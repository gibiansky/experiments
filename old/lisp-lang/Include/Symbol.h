#ifndef SYMBOL_H
#define SYMBOL_H

/* A quoted identifier is a symbol */
struct VySymbol {
	char* ident;	
};

/* Make a symbol */
VySymbol** CreateSymbol(char*);

/* Get the symbol ident */
char* GetSymbolString(VySymbol**);

/* Print a symbol to standard output */
void PrintSymbol(VySymbol**);

#endif /* SYMBOL_H */
