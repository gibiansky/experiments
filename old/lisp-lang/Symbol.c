#include "Vyion.h"

/* Create a new symbol with data */
VySymbol** CreateSymbol(char* data){
	VySymbol** symb = CreateSymbObj();
	symb[0]->ident = data;

	return symb;
}

/* Get the symbol string data */
char* GetSymbolString(VySymbol** symb){
	return symb[0]->ident;	
}

/* Print the symbol as it would appear in a parse tree */
void PrintSymbol(VySymbol** symb){
	char* string = GetSymbolString(symb);	

	/* Quote the identifier */
	printf("%s", string);
}
