#ifndef SCOPE_STACK_H
#define SCOPE_STACK_H

#include "Vyion.h"

/* A scope stack */
struct ScopeStack {
	int numElements;
	int size;
	Scope** data;
};

/* Pop and push scopes */
void Push(ScopeStack*, Scope*);
Scope* Pop(ScopeStack*);

/* Create and delete stacks */
ScopeStack* CreateScopeStack();
void DeleteScopeStack(ScopeStack*);

#endif /* SCOPE_STACK_H */
