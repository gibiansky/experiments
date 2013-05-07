#include "Vyion.h"

/* Whether the interpreter is in interactive REPL mode */
int replMode = 0;

/* Process the argument list and 'return' the values and number of arguments */
void ProcessArgumentList(Argument** funcArgs, int numFuncArgs, VyParseTree* tr, VyObject** valuesPtr, int* numArgsPtr, VyObject (*EvalFunctionToUse) (VyParseTree*)){
	/* When gathering the arguments, remember their names (if any, else NULL) */
	char** argumentNames = malloc(sizeof(char*) * (ListTreeSize(tr) - 1));

	/* Evaluate the rest of the list and store the results */
	VyObject* values = malloc(sizeof(VyObject) * (ListTreeSize(tr) - 1));
	int i;
	int numArgs = 0;
	for(i = 1; i < ListTreeSize(tr); i++){
		/* If the current argument is a ~, skip it (it will be dealt with later as a named argument marker)*/
		if(GetListData(tr, i)->type == TREE_IDENT && strcmp(GetStrData(GetListData(tr, i)), "~") == 0){
			continue;	
		}

		/* Count the number of arguments */
		numArgs++;

		/* Check whether the previous 'argument' was a ~ */
		VyParseTree* prev = GetListData(tr, i -1 );

		/* The evaluation result */
		VyObject val;

		/* If it is ~, then this is a named argument */
		if(prev != NULL && prev->type == TREE_IDENT && strcmp(GetStrData(prev),"~") == 0){
			/* Find the name and value */
			char* namedArgName = GetStrData(GetListData(GetListData(tr, i), 0));
			val = EvalFunctionToUse(GetListData(GetListData(tr, i), 1));

			/* Now remember the name and the corresponding index (in the argument array) */
			argumentNames[numArgs - 1] = namedArgName;
		} else{
			/* If it isn't a named argument, then it's name is NULL */
			argumentNames[numArgs - 1] = NULL;
			val = EvalFunctionToUse(GetListData(tr, i));
		}

		/* Subtract one from the array index because i is the index of the list, not array */
		values[numArgs - 1] = val;	
	}

	/* Now re-order the argument array for the named arguments */
	/* Make sure the argument array is valid before using it */
	if(funcArgs != NULL){

		/* First, do the required named arguments */
		int c;
		for(c = 0; c < numFuncArgs && IsNamedArg(funcArgs[c]); c++){
			/* Check whether the argument is a named one */
			Argument* currArg = funcArgs[c];
			if(IsNamedArg(currArg)){
				/* If it is, match it up with the named argument that we have by switching the order of arguments */
				char* name = currArg->name;

				int d;
				for(d = 0; d < numArgs; d++){
					/* If this is the argument we want to match it with */
					if(argumentNames[d] != NULL && strcmp(argumentNames[d], name) == 0){
						/* Switch the order */	
						VyObject temp = values[d];
						int m;
						for(m = d; m > c; m--){
							/* Move one over to the left */
							values[m] = values[m - 1];
						}
						values[c] = temp;
					}
				}
			}
		}

		/* Find where the first optional argument occurs */
		int firstOptionalArg = 0;
		while(firstOptionalArg < numFuncArgs && !IsOptionalArg(funcArgs[firstOptionalArg])){
			firstOptionalArg++;	
		}

		/* Next, sort the optional named arguments using the same method as before */
		for(c = firstOptionalArg; c < numFuncArgs && IsNamedArg(funcArgs[c]); c++){
			/* Check whether the argument is a named one */
			Argument* currArg = funcArgs[c];
			if(IsNamedArg(currArg)){
				/* If it is, match it up with the named argument that we have by switching the order of arguments */
				char* name = currArg->name;

				int d;
				for(d = 0; d < numArgs; d++){
					/* If this is the argument we want to match it with */
					if(argumentNames[d] != NULL && strcmp(argumentNames[d], name) == 0){
						/* Switch the order */	
						VyObject temp = values[d];
						int m;
						for(m = d; m > c; m--){
							/* Move one over to the left */
							values[m] = values[m - 1];
						}
						values[c] = temp;
					}
				}
			}
		}

		/* Now, make sure that optional positional arguments done get messed up by pretending they _were_ passed (use their default value) */
		for(c = firstOptionalArg; c < numFuncArgs && IsNamedArg(funcArgs[c]); c++){
			/* For every named argument, check if it really was passed by looking in the argument names array */
			int wasPassed = 0;
			int n;
			for(n = 0; n < numArgs; n++){
				/* If it WAS passed */
				if(argumentNames[n] != NULL && strcmp(argumentNames[n], funcArgs[c]->name) == 0){
					wasPassed = 1;	
				}
			}

			/* If it wasn't passed, then substitute it for its default value and move all the 
			 * values over to the right to compensate for this space */
			if(!wasPassed){
				/* Increase the amount of space needed */
				numArgs++;
				values = realloc(values, numArgs * sizeof(VyObject));

				/* Move all the values over */
				int x;
				for(x = numArgs - 1; x > c; x--){
					values[x] = values[x - 1];	
				}

				/* Now put the default value in where it should be */
				values[c] = funcArgs[c]->optArgDefault;
			}

		}
	}

	/* Return the values by storing the results in the correct memory locations */
	*valuesPtr = values;
	*numArgsPtr = numArgs;

	/* Free the argument names */
	free(argumentNames);
}

/* Perform a function given the VyFunction** and an argument list */
VyObject PerformFunction(VyFunction** func, VyParseTree* tr){
	VyObject* values;
	int numArgs;
	ProcessArgumentList(func[0]->args, func[0]->numArgs, tr, &values, &numArgs, &Eval);

	/* Calculate the result of the function */
	VyObject val = RunFunction(func, values, numArgs);
	free(values);


	/* Check whether this result is an error, if it has no associated expression, give it one */
	if(ObjType(val) == VALERROR){
		VyError** err = ObjData(val);
		if(err[0]->expr == NULL){
			err[0]->expr = tr;
		}
	}

	/* Return the result */
	return val;	
}

/* Quoted eval with and without substitutions */
VyObject QuotedEvalWithSubstitution(VyParseTree* tr){
	return QuotedEval(tr, 1);	
}
VyObject QuotedEvalWithoutSubstitution(VyParseTree* tr){
	return QuotedEval(tr, 0);	
}

/* Call a macro */
VyObject ExpandMacro(VyMacro** mac, VyParseTree* tr){
	/* Process the arguments as needed */
	VyObject* vals;
	int numArgs;
	ProcessArgumentList(mac[0]->args, mac[0]->numArgs, tr, &vals, &numArgs, &QuotedEvalWithoutSubstitution);

	char* err = CheckFunctionArguments(mac[0]->args, mac[0]->numArgs, vals, numArgs);
	if(err != NULL){
		return ToObject(CreateError(err, tr));	
	}

	/* Evaluate it as a native function */
	VyObject obj = EvalNativeFunctionOrMacro(mac[0]->args, mac[0]->numArgs, mac[0]->code, mac[0]->scp, vals, numArgs);

	if(ObjType(obj) == VALERROR){
		/* If it has no associated expression, give it one */
		VyError** err = ObjData(obj);
		if(err[0]->expr == NULL){
			err[0]->expr = tr;
		}
		return obj;
	}

	/* Evaluate the macro expansion */
	VyParseTree* tree = ObjToParseTree(obj);
	free(vals);

	return Eval(tree);

}

/* Handle an error: if in REPL mode, just continue, otherwise, exit */
void HandleError(VyObject err){
	PrintError(ObjData(err));	
	if(!replMode){
		exit(0);
	}
}

/* Convert an object into a corresponding parse tree */
VyParseTree* ObjToParseTree(VyObject obj){
	int type = ObjType(obj);
	if(type == VALLIST){
		/* Make a list parse tree and add the elements to it */
		VyParseTree* list = MakeListTree();		
		int size = ListSize(ObjData(obj));
		int i;

		for(i = 0; i < size; i++){
			AddToList(list, ObjToParseTree(ListGet(ObjData(obj), i)));		
		}

		return list;
	}
	else if(type == VALSYMB){
		/* Create an ident from symbols */
		VyParseTree* symb = MakeIdent();
		SetStrData(symb, GetSymbolString(ObjData(obj)));
		return symb;

	}
	else if(type == VALNUM){
		/* Numbers are still numbers, just in VyParseTree* form */
		VyParseTree* num = MakeNum();
		SetNumberData(num, ObjData(obj));
		return num;
	} else {
		printf("TYPE IS %d", type);fflush(stdout);
		PrintObj(obj);printf("\n");
		return NULL;	
	}
}

/* Check a string for equality */
int StrEquals(char* one, char* two){
	return (strcmp(one, two) == 0);	
}

/* Evaluate a parse tree */
VyObject Eval(VyParseTree* tr){

	/* If it is a list, then evaluate it as a function or keyword */
	if(tr->type == TREE_LIST){
		/* If you are parsing a list, use the first element to check what to do */
		VyParseTree* first = ListTreeHead(tr);

		/* If the first element is an identifier, it can be a function call or a keyword */
		if(first->type == TREE_IDENT) {
			char* funcName = GetStrData(first);

			/* Create a function on lambda */
			if(StrEquals(funcName, "lambda")){
				return ParseFunction(tr);
			}

			/* Create a macro on mambda */
			if(StrEquals(funcName, "mambda")){
				return ParseMacro(tr);
			}

			/* Create a local variable binding on set */
			else if(StrEquals(funcName, "set")){
				/* Create a variable binding and return the value held by it */
				VyParseTree* varName = GetListData(tr, 1);
				char* strVarName = GetStrData(varName);

				VyObject varValue = Eval(GetListData(tr, 2));

				/* Try looking for the object in the local scope */
				if(FindValue(GetLocalScope(), strVarName) >= 0){
					SetVariable(GetLocalScope(), strVarName, varValue);
				}
				else if(FindValue(GetCurrentFunctionScope(), strVarName) >= 0){
					SetVariable(GetCurrentFunctionScope(), strVarName, varValue);
				}
				else if(FindValue(GetGlobalScope(), strVarName) >= 0){
					SetVariable(GetGlobalScope(), strVarName, varValue);
				}

				/* Add it to the scope */
				SetVariable(GetLocalScope(), strVarName, varValue);

				return varValue;
			}

			/* Create a global variable binding on global */
			else if(StrEquals(funcName, "global")){
				/* Create a variable binding and return the value held by it */
				VyParseTree* varName = GetListData(tr, 1);
				char* strVarName = GetStrData(varName);
				VyObject varValue = Eval(GetListData(tr, 2));

				/* Add it to the scope */
				VarBinding* var = CreateVariable(strVarName, varValue);
				AddVariable(GetGlobalScope(), var);

				return varValue;
			}

			/* If statements */
			else if(StrEquals(funcName, "if")){
				/* Evaluate the condition */
				VyObject cond = Eval(GetListData(tr, 1));

				/* Check that the condition evaluates to a boolean value */
				if(ObjType(cond) == VALBOOL){
					VyBoolean** b = ObjData(cond);

					/* Based on the value of the boolean, either evaluate the first or second parts */
					if(IsTrue(b)){
						return Eval(GetListData(tr, 2));
					} else {
						if(ListTreeSize(tr) < 4){
							return ToObject(b);	
						}
						return Eval(GetListData(tr, 3));
					}
				}
				/* Dont generate double-errors */
				else if(ObjType(cond) == VALERROR){
					return cond;	
				}

				/* If the condition doesn't evaluate to a boolean, error */
				else {
					return ToObject(CreateError("Invalid boolean variable (condition must evaluate to boolean). ", GetListData(tr, 1)));
				}
			}

			/* The quote operator */
			if(StrEquals(funcName, "quote")){
				return QuotedEval(GetListData(tr, 1), 0);	
			}

			/* The substituting quote operator */
			else if(StrEquals(funcName, "quote-substitutions")){
				return QuotedEval(GetListData(tr, 1), 1);	
			}

			/* Implement tagbody/go */
			else if(StrEquals(funcName, "tagbody")){
				/* Build up the array containing the tagbody tags so go knows where to go */		
				int tags = ListTreeSize(tr) - 1;
				char** tagNames = malloc(sizeof(char*) * tags);

				int i;
				for(i = 0; i < tags; i++){
					VyParseTree* tagTree = GetListData(tr, i + 1);	
					if(tagTree->type != TREE_LIST){
						return ToObject(CreateError("Tagbody tags must be wrapped in a list. ", tr));	
					}

					VyParseTree* tagNameIdent = GetListData(tagTree, 0);
					if(tagNameIdent->type != TREE_IDENT){
						return ToObject(CreateError("Tag name must be an identifier. ", tagNameIdent));	
					}
					char* name = GetStrData(tagNameIdent);
					tagNames[i] = name;
				}

				/* Eval statements sequencially, storing the last value, and going places on go */
				VyObject lastValue;
				int currentTagNumber = 0;
				while(currentTagNumber < tags){
					VyParseTree* currentTag = GetListData(tr, currentTagNumber + 1);
					int numExprs = ListTreeSize(currentTag) - 1;

					/* Assume that you will go to the next tag afterwards */
					currentTagNumber++;

					for(i = 0; i < numExprs; i++){
						/* Evaluate the expression, go if needed, otherwise keep on eval'ing */
						VyParseTree* expr = GetListData(currentTag, i + 1);	
						lastValue = Eval(expr);	

						/* Check and jump for go */
						if(ObjType(lastValue) == VALFLOW){
							VyFlowControl** ctrl = ObjData(lastValue);	
							if(ctrl[0]->type == FLOWGO){
								/* Find the number of this tag */
								char* goTo = ctrl[0]->data;	
								int tagNumberToGoTo;
								int d;
								for(d = 0; d < tags; d++){
									if(StrEquals(tagNames[d], goTo)){
										tagNumberToGoTo = d;		
										break;
									}
								}

								/* Now jump by changing what tag it's on right now and breaking out of the sequencial eval loop */
								currentTagNumber = tagNumberToGoTo;
								break;

							}
						}
						else if(ObjType(lastValue) == VALERROR){
							return lastValue;	
						}

					}
				}

				free(tagNames);
				return lastValue;

			}

			else if(StrEquals(funcName, "go")){
				char* goToTag = GetStrData(GetListData(tr, 1));	
				return ToObject(CreateFlowControl(FLOWGO,goToTag)); 
			}

			/* Or perform the given function */
			else{
				/* Find the function with the given name */
				VyObject func = FindObjAllScopes(funcName);

				/* If it was found, continue */
				if(func >= 0){
					/* Either return the evaluation of the function */
					if(ObjType(func) == VALFUNC){
						VyObject val = PerformFunction(ObjData(func), tr);
						return val;
					}
					/* Or expand and evaluate the macro */
					else if(ObjType(func) == VALMAC){

						VyObject result = ExpandMacro(ObjData(func), tr);
						return result;
					}
					/* Otherwise, function not found */
					else{
						int size = strlen("Cannot call a non-executable data type: ") + strlen(funcName) + 1;
						char* str = malloc(size);
						sprintf(str, "%s%s", "Cannot call a non-executable data type: ", funcName);
						return ToObject(CreateError(str, tr));	
					}
				}
				else {
					int size = strlen("Callable not found: ") + strlen(funcName) + 1;
					char* str = malloc(size);
					sprintf(str, "%s%s", "Callable not found: ", funcName);
					return ToObject(CreateError(str, tr));	
				}
			}

		}
		/* If the first element is a list, it may be a lambda */
		else if(first->type == TREE_LIST){
			VyObject firstVal = Eval(first);
			/* If it is a function or macro, then run it */
			if(ObjType(firstVal) == VALFUNC){
				VyObject result = PerformFunction(ObjData(firstVal), tr);
				return result;
			}
			else if(ObjType(firstVal) == VALMAC){
				VyObject result = ExpandMacro(ObjData(firstVal), tr);
				return result;

			}
			/* If it isn't, then just treat it as a block, and evaluate each expression and return the value of the last one */
			else{
				VyObject lastValue = firstVal;
				int i;
				for(i = 1; i < ListTreeSize(tr); i++){
					lastValue = Eval(GetListData(tr, i));
					if(ObjType(lastValue) == VALERROR){
						return lastValue;	
					}
				}
				return lastValue;
			}

		}

	}

	/* Evaluate it to itself if it is a number */
	else if(tr->type == TREE_NUM){
		return ToObject(GetNumberData(tr)); 
	}

	/* If it is an ident, look for it in the current scope */
	else if(tr->type == TREE_IDENT){
		char* varName = GetStrData(tr);

		VyObject val = FindObjAllScopes(varName);

		/* If the variable isn't found, error */
		if(val < 0){
			int size = strlen("Variable not found: ") + strlen(varName) + 1;
			char* str = malloc(size);
			sprintf(str, "%s%s", "Variable not found: ", varName);
			return ToObject(CreateError(str, NULL));
		}

		return val;
	}

	/* If the type is weird, return null */
	printf("Error occured in Eval(), see last line, it SHOULD NOT GET HERE!");
	exit(0);
	return 0;

}

/* Evaluate a quoted expression: in other words, convert the parse tree into an object. Lists are still lists, identifiers are symbols, etc.  */
VyObject QuotedEval(VyParseTree* tr, int doSubstitutions){

	/* An identifier becomes a symbol */
	if(tr->type == TREE_IDENT){
		VySymbol** symb = CreateSymbol(GetStrData(tr));	
		return ToObject(symb);
	}

	/* A parse tree list becomes a value list */
	else if(tr->type == TREE_LIST){
		/* A list may be a substitution */
		if(IsSubstitution(tr) && doSubstitutions){
			/* Return the normal Eval of the data */
			VyParseTree* data = GetListData(tr, 1);
			return Eval(data);
		}

		VyList** l = CreateList();

		/* Add the elements to the list one by one */
		int listElements = ListTreeSize(tr);
		int i;
		for(i = 0; i < listElements; i++){
			VyParseTree* nextParseTree = GetListData(tr, i);

			/* Since we're in a list, check for splicing substitutions */
			if(IsSplicingSubstitution(nextParseTree) && doSubstitutions){
				/* Get the resulting list */
				VyObject list = Eval(GetListData(nextParseTree, 1));

				if(ObjType(list) != VALLIST){
					return ToObject(CreateError("A splicing substitution operates only on lists.", tr));	
				}

				/* Add each of it's elements to the list */
				int size = ListSize(ObjData(list));
				int i;
				for(i = 0; i < size; i++){
					l = ListAppend(l, ListGet(ObjData(list), i));	
				}

			}
			else{
				l = ListAppend(l, QuotedEval(nextParseTree, doSubstitutions));	
			}
		}

		return ToObject(l);
	}

	/* A number when quoted is still a number */
	else if(tr->type == TREE_NUM){
		return Eval(tr);	
	}

	printf("Whoa! Wrong type! QuotedEval()");
	exit(0);
	return -1;
}

/* Define all the built-in functions as wrappers over the other functions.
 * Note, however: all argument validation must be done IN THE WRAPPERS if possible,
 * because the real functions don't have the option to return VyError**'s, making error
 * detection and printing much harder.
 */

/* Wrappers around list functions */
VyObject LHead(VyFunction** f, VyObject* args, int argNum){
	return ListHead(ObjData(args[0]));		
}
VyObject LTail(VyFunction** f, VyObject* args, int argNum){
	return ToObject(ListTail(ObjData(args[0])));		
}
VyObject LGet(VyFunction** f, VyObject* args, int argNum){
	if(GetInt(ObjData(args[1])) > ListSize(ObjData(args[0]))){
		return ToObject(CreateError("List index out of bounds.", NULL));	
	}
	return ListGet(ObjData(args[0]), GetInt(ObjData(args[1])));		
}
VyObject LSize(VyFunction** f, VyObject* args, int argNum){
	return ToObject(CreateInt(ListSize(ObjData(args[0]))));		
}
VyObject LInsert(VyFunction** f, VyObject* args, int argNum){
	return ToObject(ListInsert(ObjData(args[0]), args[1], GetInt(ObjData(args[2]))));
}

/* Wrapper functions around arithmetic */
VyObject AddValues(VyFunction** f, VyObject* args, int argNum){
	VyNumber** result = CreateInt(0);

	int i;
	for(i = 0; i < argNum; i++){
		VyNumber** temp = AddNumbers(result, ObjData(args[i]));	
		result = temp;
	}

	VyObject resultValue = ToObject(result);
	return resultValue;
}
VyObject MultValues(VyFunction** f, VyObject* args, int argNum){
	VyNumber** result = CreateInt(1);

	int i;
	for(i = 0; i < argNum; i++){
		VyNumber** temp = MultiplyNumbers(result, ObjData(args[i]));	
		result = temp;
	}

	VyObject resultValue = ToObject(result);
	return resultValue;
}
VyObject DivValues(VyFunction** f, VyObject* args, int argNum){
	VyNumber** one = ObjData(args[0]);
	VyNumber** two = ObjData(args[1]);

	VyNumber** result = DivideNumbers(one, two);
	VyObject resultValue = ToObject(result);
	return resultValue;
}
VyObject ExpValues(VyFunction** f, VyObject* args, int argNum){
	VyNumber** one = ObjData(args[0]);
	VyNumber** two = ObjData(args[1]);

	/* A number cannot be raised to an complex power yet */
	if(two[0]->type == COMPLEX){
		return ToObject(CreateError("Cannot raise number to complex power.", NULL));	
	}

	VyNumber** result = ExponentiateNumber(one, two);
	VyObject resultValue = ToObject(result);
	return resultValue;
}
VyObject SubtractValues(VyFunction** f, VyObject* args, int argNum){
	/* Make (-) return 0 for now */
	if(argNum == 0){
		return ToObject(CreateInt(0));	
	}

	VyNumber** result = ObjData(args[0]);
	int i;
	for(i = 1; i < argNum; i++){
		VyNumber** temp = SubtractNumbers(result, ObjData(args[i]));	
		result = temp;
	}

	VyObject resultValue = ToObject(result);
	return resultValue;	
}

/* Wrappers around all the boolean and number comparison functions */
VyObject BAnd(VyFunction** f, VyObject* args, int argNum){
	VyBoolean** result = MakeTrueBool();

	int i;
	for(i = 0; i < argNum; i++){
		result = BoolAnd(result, ObjData(args[i]));	
	}

	VyObject resultValue = ToObject(result);
	return resultValue;

}
VyObject BOr(VyFunction** f, VyObject* args, int argNum){
	VyBoolean** result = MakeFalseBool();

	int i;
	for(i = 0; i < argNum; i++){
		result = BoolOr(result, ObjData(args[i]));	
	}

	VyObject resultValue = ToObject(result);
	return resultValue;

}
VyObject BXor(VyFunction** f, VyObject* args, int argNum){
	VyBoolean** result = MakeFalseBool();

	int i;
	for(i = 0; i < argNum; i++){
		result = BoolXor(result, ObjData(args[i]));	
	}

	VyObject resultValue = ToObject(result);
	return resultValue;

}
VyObject BNot(VyFunction** f, VyObject* args, int numArgs){
	return ToObject(BoolNot(ObjData(args[0])));	
}

VyObject LT(VyFunction** f, VyObject* args, int numArgs){
	VyNumber** one = ObjData(args[0]);	
	VyNumber** two = ObjData(args[1]);
	if(one[0]->type == COMPLEX || two[0]->type == COMPLEX){
		return ToObject(CreateError("Operations > and < are undefined on complex numbers.", NULL));	
	}

	return ToObject(LessThan(one, two));
}
VyObject GT(VyFunction** f, VyObject* args, int numArgs){
	VyNumber** one = ObjData(args[0]);	
	VyNumber** two = ObjData(args[1]);
	if(one[0]->type == COMPLEX || two[0]->type == COMPLEX){
		return ToObject(CreateError("Operations > and < are undefined on complex numbers.", NULL));	
	}

	return ToObject(GreaterThan(one, two));
}
VyObject LTE(VyFunction** f, VyObject* args, int numArgs){
	VyNumber** one = ObjData(args[0]);	
	VyNumber** two = ObjData(args[1]);
	if(one[0]->type == COMPLEX || two[0]->type == COMPLEX){
		return ToObject(CreateError("Operations > and < are undefined on complex numbers.", NULL));	
	}

	return ToObject(LessThanOrEqual(one, two));
}
VyObject GTE(VyFunction** f, VyObject* args, int numArgs){
	VyNumber** one = ObjData(args[0]);	
	VyNumber** two = ObjData(args[1]);
	if(one[0]->type == COMPLEX || two[0]->type == COMPLEX){
		return ToObject(CreateError("Operations > and < are undefined on complex numbers.", NULL));	
	}

	return ToObject(GreaterThanOrEqual(one, two));
}
VyObject EQ(VyFunction** f, VyObject* args, int numArgs){
	VyNumber** one = ObjData(args[0]);	
	VyNumber** two = ObjData(args[1]);

	return ToObject(Equal(one, two));
}
VyObject NEQ(VyFunction** f, VyObject* args, int numArgs){
	VyNumber** one = ObjData(args[0]);	
	VyNumber** two = ObjData(args[1]);

	return ToObject(NotEqual(one, two));
}
VyObject GeneralEQ(VyFunction** f, VyObject* args, int numArgs){
	/* All args must be same type */
	int i;
	for(i = 0; i < numArgs - 1; i++){
		if(ObjType(args[i]) !=ObjType( args[i + 1])){
			return ToObject(MakeFalseBool());	
		}
	}

	/* Now check for equality (unless it is a number, just check pointer equality) */
	for(i = 0; i < numArgs - 1; i++){
		if(ObjType(args[i]) == VALNUM){
			if(NotEqual(ObjData(args[i]), ObjData(args[i + 1]))){
				return ToObject(MakeFalseBool());	
			}
		}
		if(ObjType(args[i]) == VALSYMB){
			char* one = GetSymbolString(ObjData(args[i]));	
			char* two = GetSymbolString(ObjData(args[i + 1]));
			if(!StrEquals(one, two)){
				return ToObject(MakeFalseBool());	
			}
		}
		else{
			if(args[i] != args[i + 1]){
				return ToObject(MakeFalseBool());	
			}
		}
	}

	/* If all test passed, then they're equal */
	return ToObject(MakeTrueBool());
}

/* IO Functions */
VyObject ObjPrint(VyFunction** f, VyObject* args, int numArgs){
	int i;
	for(i = 0; i < numArgs; i++){
		PrintObj(args[i]);	
	}

	if(numArgs == 0) return 0;
	return args[numArgs - 1];
}
VyObject ObjPrintLine(VyFunction** f, VyObject* args, int numArgs){
	int i;
	for(i = 0; i < numArgs; i++){
		PrintObj(args[i]);	
		printf("\n");
	}

	if(numArgs == 0) return 0;
	return args[numArgs - 1];
}

/* Type checking functions */
VyObject IsList(VyFunction** f, VyObject* args, int numArgs){
	if(ObjType(args[0]) != VALLIST){
		return ToObject(MakeFalseBool());	
	}
	return ToObject(MakeTrueBool());	
}
VyObject IsSymbol(VyFunction** f, VyObject* args, int numArgs){
	if(ObjType(args[0]) != VALSYMB){
		return ToObject(MakeFalseBool());	
	}
	return ToObject(MakeTrueBool());	
}
VyObject IsFunction(VyFunction** f, VyObject* args, int numArgs){
	if(ObjType(args[0]) != VALFUNC){
		return ToObject(MakeFalseBool());	
	}
	return ToObject(MakeTrueBool());	
}
VyObject IsMacro(VyFunction** f, VyObject* args, int numArgs){
	if(ObjType(args[0]) != VALMAC){
		return ToObject(MakeFalseBool());	
	}
	return ToObject(MakeTrueBool());	
}
VyObject IsNum(VyFunction** f, VyObject* args, int numArgs){
	if(ObjType(args[0]) != VALNUM){
		return ToObject(MakeFalseBool());	
	}
	return ToObject(MakeTrueBool());	
}
VyObject IsError(VyFunction** f, VyObject* args, int numArgs){
	if(ObjType(args[0]) != VALERROR){
		return ToObject(MakeFalseBool());	
	}
	return ToObject(MakeTrueBool());	
}
VyObject IsBool(VyFunction** f, VyObject* args, int numArgs){
	if(ObjType(args[0]) != VALBOOL){
		return ToObject(MakeFalseBool());	
	}
	return ToObject(MakeTrueBool());	
}

/* Generate a guaranteed unique symbol */
int symbol = -1;
VyObject GenSymb(VyFunction** f, VyObject* args, int numArgs){
	symbol++;

	/* Count the digits in the symbol number */
	int digits = 0;
	int counter = 1;
	while(symbol < (10^counter)){
		counter++;
		digits++;
	}

	/* Allocate enough space for the digit string and an extra character */
	char* genSymbStr = malloc((digits + 3)*sizeof(char));
	sprintf(genSymbStr, "#-%d", symbol);

	return ToObject(CreateSymbol(genSymbStr));
}

/* A temporary namespace thing */
void ProcessFile(char*);
VyObject RequireFile(VyFunction** f, VyObject* args, int numArgs){
	VyObject name = args[0];
	VySymbol** symb = ObjData(name);
	char* fileName = GetSymbolString(symb);

	ProcessFile(fileName);

	return ToObject(MakeTrueBool());
}

int InitEvaluator(){

	InitMem();

	/* Initialize scopes (before functions because functions use scopes) */
	InitScopes();

	/* Initialize all the built-in functions */
	Argument** args = NULL;

	AddFunction("+", CreateBuiltinFunction(args, 1, &AddValues ));
	AddFunction("-", CreateBuiltinFunction(args, 1, &SubtractValues));
	AddFunction("*", CreateBuiltinFunction(args, 1, &MultValues));
	AddFunction("/", CreateBuiltinFunction(args, 2, &DivValues));
	AddFunction("**", CreateBuiltinFunction(args, 2, &ExpValues));

	AddFunction("head", CreateBuiltinFunction(args, 1, &LHead));
	AddFunction("tail", CreateBuiltinFunction(args, 1, &LTail));
	AddFunction("nth", CreateBuiltinFunction(args, 2, &LGet));
	AddFunction("len", CreateBuiltinFunction(args, 1, &LSize));
	AddFunction("insert", CreateBuiltinFunction(args, 3, &LInsert));

	AddFunction("&", CreateBuiltinFunction(args, 1, &BAnd));
	AddFunction("|", CreateBuiltinFunction(args, 1, &BOr));
	AddFunction("xor", CreateBuiltinFunction(args, 1, &BXor));
	AddFunction("not", CreateBuiltinFunction(args, 1, &BNot));

	AddFunction("<", CreateBuiltinFunction(args, 2, &LT));
	AddFunction(">", CreateBuiltinFunction(args, 2, &GT));
	AddFunction("<=", CreateBuiltinFunction(args, 2, &LTE));
	AddFunction(">=", CreateBuiltinFunction(args, 2, &GTE));
	AddFunction("=", CreateBuiltinFunction(args, 2, &EQ));
	AddFunction("!=", CreateBuiltinFunction(args, 2, &NEQ));
	AddFunction("eq", CreateBuiltinFunction(args, 2, &GeneralEQ));

	AddFunction("print", CreateBuiltinFunction(args, 1, &ObjPrint));
	AddFunction("print-line", CreateBuiltinFunction(args, 1, &ObjPrintLine));

	AddFunction("include", CreateBuiltinFunction(args, 1, &RequireFile));

	AddFunction("number?", CreateBuiltinFunction(args, 1, &IsNum));
	AddFunction("function?", CreateBuiltinFunction(args, 1, &IsFunction));
	AddFunction("list?", CreateBuiltinFunction(args, 1, &IsList));
	AddFunction("symbol?", CreateBuiltinFunction(args, 1, &IsSymbol));
	AddFunction("boolean?", CreateBuiltinFunction(args, 1, &IsBool));
	AddFunction("macro?", CreateBuiltinFunction(args, 1, &IsMacro));
	AddFunction("error?", CreateBuiltinFunction(args, 1, &IsError));

	AddFunction("unique", CreateBuiltinFunction(args, 0, &GenSymb));



	/* Initialize built-in globals */
	AddVariable(GetGlobalScope(), CreateVariable("true!", ToObject(MakeTrueBool())));
	AddVariable(GetGlobalScope(), CreateVariable("false!", ToObject(MakeFalseBool())));



	return 1;
}
void ProcessFile(char* filename){
	/* Parse the file, and if no errors exist, evaluate the expressions */
	VyParseTree* exprList = ParseFile(filename);

	if(exprList != NULL && !CheckAndPrintErrors(exprList)){
		/* Evaluate each expression and, if error, print and exit */
		int i;
		for(i = 0; i < ListTreeSize(exprList); i++){
			VyParseTree* next = GetListData(exprList, i);
			VyObject val = Eval(next);

			if(ObjType(val) == VALERROR){
				HandleError(val);	
			}

		}
	}
}

/* Given a char list, check that all parens balance */
int AllParensClosed(CharList* list){
	int counting = 1;
	int parens = 0;		

	int c;
	for(c = 0; c < Size(list); c++){
		char next = Get(list, c);	
		if(counting){
			if(next == '('){
				parens++;	
			}
			else if(next == ')'){
				parens--;	
			}
		}
	}

	if(parens == 0){
		return 1;	
	}else{
		return 0;	
	}
}

/* The read eval print loop */
void ReadEvalPrintLoop(){
	CharList** prevInputs = NULL;
	int numInputs = 0;
	char c;

	/* Let the user enter expressions and evaluate them */
	while(c != EOF){
		printf("V >> ");	
		fflush(stdout);

		/* Get user input */
		CharList* strList = MakeCharList();	
		while(1){
			c = getchar();
			/* On entered newline, if all parenthesis balance, stop, otherwise continue data enterage */
			if(c == '\n' && AllParensClosed(strList)){
				break;
			}else if(c == '\n'){
				printf("     ");	
			}

			Add(strList, c);
		}

		numInputs++;
		prevInputs = realloc(prevInputs, numInputs*sizeof(CharList*));
		prevInputs[numInputs - 1] = strList;

		/* Lex, parse, eval */
		char* str = ToStr(strList);

		/* For convenience, exit when the user types "exit" and "quit" */
		if(StrEquals(str, "exit") || StrEquals(str, "quit")){
			exit(1);	
		}

		Lex(str);
		if(GetNumTokens() == 0){
			continue;	
		}

		/* Look for errors, if none found, eval and print result */
		VyParseTree* tree = Parse();
		if(!CheckAndPrintErrors(tree)){
			VyObject val = Eval(tree);
			printf("\n");
			PrintObj(val);
			printf("\n");
		}

		/* Free various resources */
		CleanLexer();
		CleanParser();
		free(str);
	}
}

int main(int argc, char** argv){
	InitEvaluator();

	/* If given filenames, process all that are given, otherwise enter the read-eval-print-loop */
	if(argc >= 2){
		replMode = 0;
		int file;
		for(file = 1; file < argc; file++){
			ProcessFile(argv[file]);	
		}
	}
	else{
		replMode = 1;
		ReadEvalPrintLoop();
	}

	/* Free memory */
	FreeHeap(GetMemoryHeap());

	return 1;
}
