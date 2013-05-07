#include "Vyion.h"

/* Create a variable */
VarBinding* CreateVariable(char* name, VyObject val){
	VarBinding* var = malloc(sizeof(VarBinding));

	/* Clone the name string so that deleting the variable has no side effects */
	var->name = strdup(name);
	var->val = val;

	return var;
}

/* Delete a variable (doesn't delete the value)  */
void DeleteVariable(VarBinding* var){
	free(var->name);
	free(var);
}

/* Get the variable name */
char* GetVarName(VarBinding* var){
	return var->name;   
}

/* Get the variable value */
VyObject GetVarValue(VarBinding* var){
	return var->val;	
}
