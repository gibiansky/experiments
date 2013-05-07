#ifndef  PARSER_H
#define  PARSER_H

#include "Vyion.h"

/* A routine to parse a file (wraps file into a list, since a file consists of many expressions */
VyParseTree* ParseFile(char*);

/* A function that parses whatever happens to be in the lexer */
VyParseTree* Parse();

/* Print the parse tree (for debugging) */
void PrintTree(VyParseTree*);

/* Look for and print errors, return if there were any */
int CheckAndPrintErrors(VyParseTree*);

/* Clean all the resources of the parser */
void CleanParser();

#endif /* PARSER_H */
