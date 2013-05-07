#include "Vyion.h"

/***** Create function objects *****/

/* Create a builtin function */
VyFunction** CreateBuiltinFunction(Argument** args, int argNum,  VyObject (*builtin)(VyFunction**, VyObject*,int)){
	VyFunction** func = CreateFuncObj();
	func[0]->numArgs = argNum;
	func[0]->args = args;
	func[0]->EvalFunction = builtin;

	return func;
}

/* Create a native function */
VyFunction** CreateNativeFunction(Argument** args, int argNum,  VyParseTree* code, Scope* funcScope){
	/* Use the builtin function EvalNativeFunction, which evaluates a ParseTree as a */
	/* function, to create a VyFunction** for a native lisp function */
	VyFunction** nativeFunc = CreateBuiltinFunction(args, argNum,  &EvalNativeFunction);
	nativeFunc[0]->code = code;
	nativeFunc[0]->scp = funcScope;
	return nativeFunc;
}

/* Set a function scope */
void SetFunctionScope(VyFunction** f, Scope* scp){
	f[0]->scp = scp;   
}

/***** Functions dealing with Argument*s *****/

/* Create an argument */
Argument* CreateArgument(int argCode, char* symbName, int valType){
	Argument* arg = malloc(sizeof(Argument));
	arg->argCode = argCode;
	arg->name = symbName;
	arg->type = valType;
	arg->optArgDefault = -1;
	return arg;
}

/* Use the argument codes to check if it is an optional argument */
inline int IsOptionalArg(Argument* arg){
	/* All optional arguments have an odd argument code */
	if(arg->argCode == ARGOPTIONAL || arg->argCode == ARGNAMEDOPTIONAL){
		return 1;	
	}

	return 0;
}

/* Use the argument codes to check if it is a rest argument */
int IsRestArg(Argument* arg){
	/* All rest arguments have an argument codes greater than or equal to 100 */
	if(arg->argCode == ARGREST){
		return 1;	
	}

	return 0;
}

/* Use the argument code to check if it is a named argument */
int IsNamedArg(Argument* arg){
	/* Named arguments are greater than 1 and less than 100 or greater than 101 */
	if(arg->argCode == ARGNAMED || arg->argCode == ARGNAMEDOPTIONAL){
		return 1;	
	}

	return 0;
}

/***** Functions for running both built-in and native functions */

/* Check the validity of a function's arguments */
char* CheckFunctionArguments(Argument** funcArgs, int funcNumArgs, VyObject* args, int numArgs){
	/* Make sure there are arguments to validate against */
	if(funcArgs == NULL){
		return NULL;	
	}
	if(funcNumArgs == 0){
		if(numArgs > 0){
			char* message = "Too many arguments to function.";
			return (message);
		}
		return NULL;
	}

	/* Total number of arguments */
	/* Check if this function has a rest argument */
	if(!IsRestArg(funcArgs[funcNumArgs - 1])){
		/* If it doesn't, check that too many arguments aren't given */
		if(numArgs > funcNumArgs){
			char* message = "Too many arguments to function.";
			return (message);
		}
	}

	/* Find the number of required args */
	int requiredArgs = 0;
	while(funcNumArgs > requiredArgs && !IsOptionalArg(funcArgs[requiredArgs])){
		requiredArgs++;	
	}

	/* Check that all of them have been satisfied */
	if(numArgs < requiredArgs){
		/* If they haven't, error */
		return ("Unsatisfied arguments.");
	}

	return NULL;
}

/* Bind arguments to variables in the local scope */
void CreateArgumentVariableBindings(Argument** funcArgs, int funcNumArgs, VyObject* args, int numArgs){

	/* Bind all given values to variables */
	int i;
	for(i = 0; i < numArgs; i++){
		Argument* currArg = funcArgs[i];
		char* argName = currArg->name;

		/* If it is a rest argument, then put the rest of the arguments in a list and bind that list to the variable, then exit */
		if(IsRestArg(currArg)){
			/* Put the rest of the arguments in a list */
			int nonRestArgs = i;
			VyList** rest = CreateList();
			int c;
			for(c = nonRestArgs; c < numArgs; c++){
				rest = ListAppend(rest, args[c]);
			}

			/* Bind the list value to the name */
			VyObject listVal = ToObject(rest);
			SetVariable(GetLocalScope(), argName, listVal);

			/* Exit this procedure, since there are no more arguments left to bind */
			return;
		}

		/* Otherwise, just set the variable */
		SetVariable(GetLocalScope(), argName, args[i]);
	}

	/* Now, bind optional arguments that haven't yet been bound */
	for(i = numArgs; i < funcNumArgs; i++){
		Argument* currArg = funcArgs[i];
		SetVariable(GetLocalScope(), currArg->name, currArg->optArgDefault);
	} 
}

/* Evaluate a native function, which can be a macro too */
VyObject EvalNativeFunctionOrMacro(Argument** funcArgs, int funcNumArgs, VyParseTree* code, Scope* scp, VyObject* args, int numArgs){
	/* Push the previous scope on the scope stack and add a new scope for this function call */
	PushScope(GetLocalScope());
	SetLocalScope(CreateScope());

	/* Since the arguments are valid, bind them to variables in the local */
	CreateArgumentVariableBindings(funcArgs, funcNumArgs, args, numArgs);

	/* Set the current function scope */
	SetCurrentFunctionScope(scp);

	/* Keep track of the last value, for this is what is returned */
	VyObject lastValue;

	/* Sequencially evaluate each expression and store the result in the last value */
	int i;
	for(i = 0; i < ListTreeSize(code); i++){
		lastValue = Eval(GetListData(code, i)); 

		/* If an error occurred, return it */
		if(ObjType(lastValue) == VALERROR){
			return lastValue;	
		}	
	}

	/* Delete the scope (NOTE: REMOVE THIS LATER WHEN GC COMES AROUND) */
	DeleteScope(GetLocalScope());

	/* Return to the previous scope */
	SetLocalScope(PopScope());

	return lastValue;   

}

/* Evaluate a native function (not a macro)  */
VyObject EvalNativeFunction(VyFunction** func, VyObject* args, int numArgs){
	return EvalNativeFunctionOrMacro(func[0]->args, func[0]->numArgs, func[0]->code, func[0]->scp, args, numArgs);
}

/* Evaluate a function for the given arguments */
VyObject RunFunction(VyFunction** func, VyObject* args, int numArgs){
	/* Check the function's arguments, and if they are invalid, error */
	char* err = CheckFunctionArguments(func[0]->args, func[0]->numArgs, args, numArgs);
	if(err != NULL){
		return ToObject(CreateError(err, NULL));	
	}

	/* Evaluate the function by calling the function pointer in it */
	return func[0]->EvalFunction(func, args, numArgs);

}

/***** Functions for parsing, storing, and retrieving functions */

/* Parse a single argument */
Argument* ParseArgument(VyParseTree* arg, VyParseTree* prevTree){
	/* Create an argument with default values */
	Argument* result = CreateArgument(0, NULL, VALUNDEF);

	/* A simple argument */
	if(arg->type == TREE_IDENT){
		/* Set the variable name */
		result->name = GetStrData(arg);
	}

	/* An optional, named, or rest argument */
	else if(arg->type == TREE_LIST){
		/* Check the previous parse tree to see whether it is optional, named, or rest */
		char* lastTreeIdent = GetStrData(prevTree);

		/* Optional */
		if(strcmp(lastTreeIdent, "?") == 0){
			/* Make it an optional argument */
			result->argCode = ARGOPTIONAL;

			/* Find the name */
			result->name = GetStrData(GetListData(arg, 0));

			/* Find the default value */
			result->optArgDefault = Eval(GetListData(arg, 1));

		}

		/* Named */
		else if(strcmp(lastTreeIdent, "~") == 0){
			/* Make it named */
			result->argCode = ARGNAMED;

			/* Get the name */
			char* namedName = GetStrData(GetListData(arg, 0));
			result->name = namedName;
		}

		/* Rest */
		else if(strcmp(lastTreeIdent, "&") == 0){
			/* Make it a rest argument */
			result->argCode = ARGREST;

			/* Get the argument name */
			result->name = GetStrData(GetListData(arg, 0));
		}

		/* Named optional */
		else if(strcmp(lastTreeIdent, "~?") == 0){
			/* Make it a named optional argument */
			result->argCode = ARGNAMEDOPTIONAL;

			/* Get the name and default value */
			result->name = GetStrData(GetListData(arg, 0));
			result->optArgDefault = Eval(GetListData(arg, 1));
		}
	}

	return result;
}

/* Parse a function's arguments */
Argument** ParseFunctionArguments(VyParseTree* argList, int* storeNumArgs, char** errorStore){
	/* Find the number of arguments (but don't count ? ~ and &s) */
	int argNums = 0;
	int c;
	for(c = 0; c < ListTreeSize(argList); c++){
		/* Get the argument and check if it is ? or & or ~*/
		VyParseTree* currentArg = GetListData(argList, c);

		/* If it isn't, increment the number of arguments */
		if(currentArg->type == TREE_IDENT){
			char* argStr = GetStrData(currentArg);
			/* Check that it isn't a ? or ~ */
			if(strcmp("?", argStr) != 0 && strcmp("~", argStr) != 0 && strcmp("~?", argStr) != 0){
				argNums++;	
			}

			/* If it is a &, this is the last argument, so break (it has already been counted above) */
			if(strcmp("&", argStr) == 0){
				break;
			}
		}else{
			argNums++;	
		}
	}
	*storeNumArgs = argNums;

	/* Mallocate an array of arguments of the right size */
	Argument** argArray = malloc( sizeof(Argument*) * (*storeNumArgs) );

	/* When parsing arguments, make sure that optional arguments are all after normal ones */
	int optionArgumentsStarted = 0;

	/* Parse each argument */
	int i;
	int argumentsFilled = 0;
	for(i = 0; i < ListTreeSize(argList); i++){
		/* Get the previous argument (or NULL if this is first one) */
		VyParseTree* prev = NULL;
		if(i > 0) {
			prev = GetListData(argList, i - 1);
		}

		/* Check that this isn't the symbol for optional or rest arguments */
		VyParseTree* currentArg = GetListData(argList, i);

		/* If it is a special symbol, not an argument, just skip this argument */
		if(currentArg->type == TREE_IDENT && (strcmp("?", GetStrData(currentArg)) == 0 || strcmp("~?", GetStrData(currentArg)) == 0 || strcmp("~", GetStrData(currentArg)) == 0 || (strcmp("&", GetStrData(currentArg)) == 0))){
			continue;	
		}

		/* Parse each separate argument */
		Argument* arg = ParseArgument(currentArg, prev);

		/* Optional arguments already? */
		if(IsOptionalArg(arg)){
			optionArgumentsStarted = 1;	
		}

		/* Make sure optional arguments come after normal ones, and if not, error */
		if(optionArgumentsStarted && !IsOptionalArg(arg)){
			/* It can also be a rest argument */
			if(!IsRestArg(arg)){
				*errorStore = "Optional arguments must come last.";	
				return NULL;
			}
		}

		/* Make sure rest arguments are last */
		if(IsRestArg(arg) && i != ListTreeSize(argList) - 1){
			*errorStore = "Rest arguments must come last.";
			return NULL;
		}


		/* Add the argument to the argument array */
		argArray[argumentsFilled] = arg;
		argumentsFilled++;

		/* If this is a rest argument, then no more arguments are possible */
		if(IsRestArg(arg)){
			break;	
		}
	}

	/* Next, order the arguments in the following order: required named, required positional, optional named, required named, rest. */

	/* Use a modified version of Bubble sort */
	int changes = 1;
	int firstOptArg = 0;

	/* First sort the required arguments */
	while(changes){
		changes = 0;
		int d;

		/* Iterate through all the elements until you reach the end or an optional argument */
		for(d = 0; d < argNums - 1 && !IsOptionalArg(argArray[d + 1]); d++){
			/* Store the starting place for the next sorting routine */
			firstOptArg = d;

			/* Move named arguments to the left */
			if(IsNamedArg(argArray[d + 1]) && !IsNamedArg(argArray[d])){
				Argument* temp = argArray[d];
				argArray[d] = argArray[d + 1];
				argArray[d + 1] = temp;

				changes = 1;
			}
		}

	}

	/* Next, sort optional arguments */
	changes = 1;
	while(changes){
		changes = 0;
		int d;
		/* Iterate through all the elements until you reach the end, starting at the first optional argument 
		 * (but make sure to add two so that it doesn't accidentally switch an argument too far to the left) */
		for(d = firstOptArg + 2; d < argNums - 1; d++){
			/* Move named arguments to the left */
			if(IsNamedArg(argArray[d + 1]) && !IsNamedArg(argArray[d])){
				Argument* temp = argArray[d];
				argArray[d] = argArray[d + 1];
				argArray[d + 1] = temp;

				changes = 1;

			}
		}
	}

	return argArray;
}

/* Parse a nameless function given a lambda list */
VyObject ParseFunction(VyParseTree* code){
	/* Parse the function arguments */
	VyParseTree* args = GetListData(code, 1);
	int numArguments = 0;
	char* err = NULL;
	Argument** arguments = ParseFunctionArguments(args, &numArguments, &err);
	if(err != NULL){
		return ToObject(CreateError(err, code));	
	}

	/* Take the rest of the expressions in the lambda as code */
	VyParseTree* exprList = MakeListTree();
	int i;
	for(i = 2; i < ListTreeSize(code); i++){
		AddToList(exprList, GetListData(code, i));  
	}

	/* Take variables from the current function scope and the local scope */
	Scope* funcScope = GetCurrentFunctionScope();
	Scope* localScope = GetLocalScope();

	/* Make sure the local scope isn't the global scope */
	if(localScope == GetGlobalScope()) {
		localScope = NULL; 
	}

	/* Merge the two scopes to get the current function scope */
	Scope* closureScope = MergeScopes(funcScope, localScope);

	/* Create the function from the data gathered */
	VyFunction** func = CreateNativeFunction(arguments, numArguments, exprList, closureScope);
	return ToObject(func);
}

/* Add a nameless function (from a lambda) to the function list, after giving it a name */
void AddFunction(char* asName, VyFunction** func){
	/* Add the function to the global scope */
	AddVariable(GetGlobalScope(), CreateVariable(asName, ToObject(func)));
}
