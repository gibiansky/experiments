#ifndef TOKEN_H
#define TOKEN_H

/* A position of a token in the given code */
struct Position {
	int line;
	int indent;
	int character;
};

/* A lexer token */
struct VyToken {
	int type;
	char* data;
	Position* pos;
};

/* Create a token with no associated data of given type */
VyToken* EmptyToken(int);

/* Create a token of a given type with associated string data */
VyToken* DataToken(int,char*);

/* Set the position of a token */
void SetTokenPosition(VyToken*, int, int, int);

/* Print a position (line and character) */
void PrintPosition(Position*);

/* Find the line or character position of a token */
int GetLine(VyToken*);
int GetCharacter(VyToken*);
int GetIndent(VyToken*);

/* Whether the token  has a known position */
int HasKnownPosition(VyToken*);

/* Whether the token is an empty token (i.e., no associated string data) */
int IsEmptyToken(VyToken*);

/* Delete the token data and free used memory */
void DeleteToken(VyToken*);

#endif /* TOKEN_H */
