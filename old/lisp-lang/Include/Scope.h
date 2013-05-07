#ifndef SCOPE_H
#define SCOPE_H

#include "Vyion.h"

/* A variable scope */
struct Scope {
	VarBinding** vars;
	int size;
};

/***** Functions to deal with scope data structures *****/

/* Create a scope */
Scope* CreateScope();

/* Find a variable in a scope; if it doesn't exist, return NULL; if it doesn, return it's value. */
VyObject FindValue(Scope*, char*);

/* Set a variable (may need to add it first) */
void SetVariable(Scope*, char*, VyObject);

/* Add a variable to a scope */
void AddVariable(Scope*, VarBinding*);

/* Print the concents of a scope */
void PrintScopeContents(Scope*);

/* Merge two scopes into one */
Scope* MergeScopes(Scope*, Scope*);

/* Destroy a scope */
void DeleteScope(Scope*);

/***** Functions to deal with the program's scope *****/

/* Get the global scope */
Scope* GetGlobalScope();

/* Add or remove scopes to the function scope stack */
void PushScope(Scope*);
Scope* PopScope();

/* Get the local scope */
Scope* GetLocalScope();

/* Get the current function scope */
Scope* GetCurrentFunctionScope();

/* Set the current function scope */
void SetCurrentFunctionScope(Scope*);

/* Set the local scope */
void SetLocalScope(Scope*);

/* Find a value in all currently accesible scopes */
VyObject FindObjAllScopes(char*);

/* Initialize scopes */
void InitScopes();

#endif /* SCOPE_H */
