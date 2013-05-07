#include "Vyion.h"

/* Create a token with no associated data */
VyToken* EmptyToken(int type){
	VyToken* tok = malloc(sizeof(VyToken));
	tok->type = type;
	tok->data = NULL;
	tok->pos = NULL;
	return tok;
}

/* Create a token with associated string data */
VyToken* DataToken(int type, char* data){
	VyToken* tok = EmptyToken(type);
	tok->data = data;
	return tok;
}

/* Set the position of a token in the program */
void SetTokenPosition(VyToken* tok, int line, int character, int indent){
	if(tok->pos == NULL){
		tok->pos = malloc(sizeof(Position));
	}
	tok->pos->line = line;
	tok->pos->character = character;
	tok->pos->indent = indent;
}

/* Print a position */
void PrintPosition(Position* pos){
	/* Increment the line and character so they start at 1 and not 0 */
	if(pos != NULL)
		printf("line %d, character %d", pos->line + 1, pos->character + 1);	
}

/* Whether the token is an empty token (i.e. has no associated data) */
int IsEmptyToken(VyToken* tok){
	if(tok->data == NULL){
		return 1;
	}
	else{
		return 0;
	}
}

/* Find the location of the token */
int GetLine(VyToken* tok){
	if(tok->pos == NULL){
		return -1;
	}else{
		return tok->pos->line;
	}
}
int GetCharacter(VyToken* tok){
	if(tok->pos == NULL){
		return -1;
	}else{
		return tok->pos->character;
	}
}
int GetIndent(VyToken* tok){
	if(tok->pos == NULL){
		return -1;
	}else{
		return tok->pos->indent;
	}
}

/* Whether the position of the token has been marked */
int HasKnownPosition(VyToken* tok){
	if(tok->pos == NULL){
		return 0;
	}else{
		return 1;
	}
}

/* Free the used memory */
void DeleteToken(VyToken* tok){
	/* If needed, free the string data as well */
	if(!IsEmptyToken(tok)){
		free(tok->data);
	}

	/* Free the position data */
	if(tok->pos != NULL){
		free(tok->pos);
	}

	free(tok);
}
