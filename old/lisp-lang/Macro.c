#include "Vyion.h"

/* Create a macro */
VyMacro** CreateMacro(Argument** args, int numArguments, VyParseTree* code, Scope* scp){
	VyMacro** mac = CreateMacroObj();	
	mac[0]->args = args;
	mac[0]->numArgs = numArguments;
	mac[0]->code = code;
	mac[0]->scp = scp;

	return mac;
}

/* Evaluate a macro and return the resulting parse tree */
VyParseTree* EvalMacro(VyMacro** mac, VyObject* args, int numArgs){
	/* Check the macro arguments */
	char* err = CheckFunctionArguments(mac[0]->args, mac[0]->numArgs, args, numArgs);
	if(err != NULL){
		HandleError(ToObject(CreateError(err, NULL)));	
	}

	/* Evaluate it as a native function */
	VyObject obj = EvalNativeFunctionOrMacro(mac[0]->args, mac[0]->numArgs, mac[0]->code, mac[0]->scp, args, numArgs);
	if(ObjType(obj) == VALERROR){
		HandleError(obj);	
	}
	VyParseTree* tree = ObjToParseTree(obj);

	return tree;
}

/* Parse a macro */
VyObject ParseMacro(VyParseTree* code){
	/* Parse the function arguments */
	VyParseTree* args = GetListData(code, 1);
	int numArguments = 0;
	char* error = NULL;
	Argument** arguments = ParseFunctionArguments(args, &numArguments, &error);
	if(error != NULL){
		return ToObject(CreateError(error, code));	
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
	VyMacro** mac = CreateMacro(arguments, numArguments, exprList, closureScope);
	return ToObject(mac);	
}
