#ifndef VARIABLE_H
#define VARIABLE_H

#include "Vyion.h"

/* A variable binding */
struct VarBinding {
	char* name;
	VyObject val;
};

/* Create a binding */
VarBinding* CreateVariable(char*,VyObject);

/* Retrieve the name or value of a variable */
char* GetVarName(VarBinding*);
VyObject GetVarValue(VarBinding*);

/* Free the memory */
void DeleteVariable(VarBinding*);

#endif /* VARIABLE_H */
