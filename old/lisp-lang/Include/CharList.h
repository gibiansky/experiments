#ifndef CHAR_LIST_H
#define CHAR_LIST_H

/* CharList is a utility for the lexer, mostly, which is just a list of characters. 
 * Like an expandable string. 
 */

/* A list of characters which can be expanded (currently, a linked list) */
struct CharList {
	char val;
	struct CharList* next;
};

/* Print the contents of the list to standard output */
void Print(CharList*);

/* Add a character to the list */
void Add(CharList*, char);

/* Free the used memory */
void Delete(CharList*);

/* Create a character list. (Safer than creating it yourself) */
CharList* MakeCharList();

/* Get the character at a set position in the list */
char Get(CharList*, int);

/* Convert the character list into a string */
char* ToStr(CharList*);

/* Find the size of the character list */
int Size(CharList*);

#endif /* CHAR_LIST_H */
