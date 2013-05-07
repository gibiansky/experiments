#ifndef LEXER_H
#define LEXER_H

#include "Vyion.h"

/* The lexer is the part of the interpreter which deals with pure textual
 * input. What it does is it reads the input as characters, and emits 
 * tokens (in the form of VyToken*) so that the parser doesn't have to deal with
 * pesky things such as whitespace. The lexer is used by the parser, and makes life a 
 * whole lot better. 
 */

/***** Functions to access the current state of the lexer *****/

/* Get the token list */
VyToken** GetTokenList();

/* Get the next token */
VyToken* GetNextToken();

/* Find out if there are more tokens */
int MoreTokensExist();

/* Backtrack on the current token (i.e. next time, GetNextToken() will return the previous token) */
int BacktrackToken();

/* Returns the next token, but doesn't change the next outcome of GetNextToken() */
VyToken* GetLookAheadToken();

/* Find the total number of tokens for the last processed data */
int GetNumTokens();

/* Free the used memory and reset the lexer to its initial state */
void CleanLexer();

/***** Functions for tokenizing data *****/

/* Process a whole file */
void LexFile(char*);

/* Process a string */
void Lex(char*);

/***** Debugging functions *****/

/* Print the token list (for debugging) */
void PrintTokenList();

/* Print a token */
void PrintToken(VyToken*);

#endif /* LEXER_H */
