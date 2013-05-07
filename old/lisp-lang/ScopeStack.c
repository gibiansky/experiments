#include "Vyion.h"

void Push(ScopeStack* stack, Scope* new){
	/* Check if you need more memory, and if you do, allocate it */
	if(stack->size < stack->numElements + 1){
		stack->data = realloc(stack->data, sizeof(Scope*)*(stack->size + 1));
		stack->size++;
	}

	/* Store the new scope and record it */
	stack->data[stack->numElements] = new;
	stack->numElements++;
}

/* Pop a scope off the stack */
Scope* Pop(ScopeStack* stack){
	/* Make sure there is something to pop */
	if(stack->numElements <= 0){
		return NULL;	
	}

	/* Decrease the number of elements and return the popped element */
	stack->numElements--;
	return stack->data[stack->numElements];
}

/* Create a scope stack */
ScopeStack* CreateScopeStack(){
	ScopeStack* stack = malloc(sizeof(ScopeStack));
	stack->numElements = 0;
	stack->size = 0;
	stack->data = NULL;

	return stack;
}

/* Delete the stack */
void DeleteScopeStack(ScopeStack* stack){
	if(stack != NULL){
		/* Free all the Scope*s */
		int i;
		for(i = 0; i < stack->size; i++){
			free(stack->data[i]);   
		}

		/* Free the stack itself */
		free(stack);
	}
}
