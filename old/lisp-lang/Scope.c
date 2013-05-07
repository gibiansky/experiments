#include "Vyion.h"

/***** Dealing with the scope data structure *****/

/* Create an empty scope */
Scope* CreateScope(){
	Scope* scp = malloc(sizeof(Scope));
	scp->vars = NULL;
	scp->size = 0;

	return scp;
}

/* Find a variable value */
VyObject FindValue(Scope* scp, char* varName){
	/* If scope is null, return null */
	if(scp == NULL){
		return -1;	
	}

	/* Iterate through all the variables and compare their names */
	int i;  
	for(i = 0; i < scp->size; i++){
		/* Retrieve the variable and name at that index */
		VarBinding* var = scp->vars[i];
		char* currentVarName = GetVarName(var);

		/* Compare names */
		if(strcmp(varName, currentVarName) == 0){
			/* If they are the same, return the value */
			return GetVarValue(var);	
		}
	}

	/* If the variable wasn't found, return < 0 */
	return -1;
}

/* Add a variable to a scope */
void AddVariable(Scope* scp, VarBinding* var){
	/* Allocate more memory for the new variable */
	int scopeSize = scp->size;
	scp->vars = realloc(scp->vars, sizeof(VarBinding*) * (scopeSize + 1));

	/* Add the variable and increment size */
	scp->vars[scopeSize] = var;
	scp->size++;
}

/* Set a variable value (independent of whether it already exists or not( */
void SetVariable(Scope* scp, char* varName, VyObject val){
	/* If the variable doesn't exist yet, then add it, otherwise, update it */
	if(FindValue(scp, varName) < 0){
		AddVariable(scp, CreateVariable(varName, val));
	}else{
		/* Iterate through all the variables and compare their names */
		int i;  
		for(i = 0; i < scp->size; i++){
			/* Retrieve the variable and name at that index */
			VarBinding* var = scp->vars[i];
			char* currentVarName = GetVarName(var);

			/* Compare names */
			if(strcmp(varName, currentVarName) == 0){
				/* If they are the same, update the value and exit */
				var->val = val;
				return;	
			}
		}
	}	
}

/* Print the contents of a scope to stdout */
void PrintScopeContents(Scope* scp){
	/* Cycle through and print each variable name and it's type */
	int i;
	printf("\n--- Scope Contents ---\n");
	if(scp->size == 0) {
		printf("No values in scope.");  
	}
	else{
		for(i = 0; i < scp->size; i++){
			printf("Variable: %s - %d\n", scp->vars[i]->name, ObjType(scp->vars[i]->val));
		}
	}
}

/* Merge two scopes (both old scopes are unchanged) */
Scope* MergeScopes(Scope* one, Scope* two){
	Scope* new = CreateScope();

	int i;

	/* Add the variables from scope one */
	if(one != NULL){
		for(i = 0; i < one->size; i++){
			AddVariable(new, one->vars[i]); 
		}
	}

	/* And variables from scope two */
	if(two != NULL){
		for(i = 0; i < two->size; i++){
			AddVariable(new, two->vars[i]); 
		}
	}

	return new;
}

/* Destroy the scope and free used memory */
void DeleteScope(Scope* scp){
	if(scp != NULL){
		/* Delete all the variables */
		int i;
		for(i = 0; i < scp->size; i++){
			DeleteVariable(scp->vars[i]);   
		}

		/* Free the array of variables */
		free(scp->vars);

		/* Delete the scope itself */
		free(scp);
	}

}

/***** Dealing with program scopes *****/
Scope* globalScope;
Scope* currentFunctionScope;
Scope* localScope;

ScopeStack* functionScopes;

/* Inititialize all the scopes */
void InitScopes(){
	/* Create a global scope */
	globalScope = CreateScope();

	/* Before any functions are called, the global scope IS the local scope */
	localScope = globalScope;

	/* Create a scope stack for the functions */
	functionScopes = CreateScopeStack();

}

/* Return the global scope */
Scope* GetGlobalScope(){
	return globalScope; 
}

/* Manipulate the scope stack */
void PushScope(Scope* scp){
	Push(functionScopes, scp);  
}

Scope* PopScope(){
	return Pop(functionScopes);
}

/* Return the local scope */
Scope* GetLocalScope(){
	return localScope;  
}

/* Return the current function scope */
Scope* GetCurrentFunctionScope(){
	return currentFunctionScope;	
}

/* Set the current function scope */
void SetCurrentFunctionScope(Scope* scp){
	currentFunctionScope = scp; 
}

/* Set the local scope */
void SetLocalScope(Scope* scp){
	localScope = scp;   
}

/* Find a variable in the currently accessible scopes - that is, local, global, and closure scope */
VyObject FindObjAllScopes(char* name){
	/* Try looking for the object in the local scope */
	VyObject obj = FindValue(GetLocalScope(), name);
	if(obj >= 0){
		return obj; 
	}

	/* If not found, try function scope */
	obj = FindValue(GetCurrentFunctionScope(), name);
	if(obj >= 0){
		return obj; 
	}

	/* If still not found, try global scope */
	obj = FindValue(GetGlobalScope(), name);
	if(obj >= 0){
		return obj; 
	}

	/* If it wasn't found at all, return NULL */
	return -1;

}

