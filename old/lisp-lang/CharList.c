#include "Vyion.h"

/* Make a new character list and initialize the next node to NULL */
CharList* MakeCharList(){
	CharList* c = malloc(sizeof(CharList));
	c->next = NULL;
	return c;
}

/* Add another node to the list */
void Add(CharList* list, char c){
	/* If this is the last node, then add the character to it and add another empty node for the future */
	if(list->next == NULL){
		/* Create a new node that will be used in future additions*/
		list->next = MakeCharList();

		/* Add the character to THIS node */
		list->val = c;

	}
	/* If it isn't the last node, then continue on to the next node in the list */
	else {
		Add(list->next, c); 
	}
}

/* Find the character at index n */
char Get(CharList* list, int n){
	/* If it's this node, return it; otherwise, go on to the next node */
	if(n == 0){
		return list->val;
	}else{
		return Get(list->next, n - 1);
	}
}

/* Convert the CharList to a string */
char* ToStr(CharList* list){
	/* Allocate room for the string */
	int list_size = Size(list);
	char* str = malloc(sizeof(char)*list_size + 1);


	/* Collect the string characters */
	int c;
	for(c = 0; c < list_size; c++){
		str[c] = Get(list,c);
	}

	/* End the string (with a ASCII 0) */
	str[list_size] = '\0';

	/* Return the string */
	return str;
}

int Size(CharList* list){
	if(list->next == NULL){
		return 0;
	}else{
		return Size(list->next) + 1;
	}
}

/* Print the contents of the list recursively */
void Print(CharList* list){
	if(list->next != NULL){
		printf("%c", list->val);
		Print(list->next);
	}
}

/* Delete the list */
void Delete(CharList* list){
	/* If this is the last added one, free it, otherwise, 
	 * free the next node first and then free this node. */
	if(list->next == NULL){
		free(list);
	}else{
		Delete(list->next);
		free(list);
	}
}

