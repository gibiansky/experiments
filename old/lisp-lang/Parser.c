#include "Vyion.h"

VyParseTree* Parse();

/* Parse a generic list (either () or []) */
VyParseTree* ParseListGeneric(int endTokenType){
	/* Create a list with no items in it */
	VyParseTree* list = MakeListTree();

	/* Make sure there is more to read and that the file isn't over */
	if(!MoreTokensExist()){
		return ParseError("Unclosed list at end of file.");	
	}

	/* While the list, isn't over add items to it */
	VyToken* nextToken;
	while((nextToken = GetLookAheadToken())->type != endTokenType){
		/* Add the next element, which is recieved from Parse(), to the list */
		VyParseTree* nextElement = Parse();
		AddToList(list, nextElement);


		/* If there are no more tokens, then a parenthesis is unclosed */
		if(!MoreTokensExist()) {
			VyParseTree* error = ParseError("Unclosed list");
			SetPosition(error, nextToken->pos);
			AddToList(list, error);
			return list;
		}

	}
	GetNextToken();


	return list;

}

/* Parse a list */
VyParseTree* ParseList(){
	return ParseListGeneric(CPAREN);
}

/* Parse a bracketed list as a quoted list */
VyParseTree* ParseBracketedList(){
	/* Same procedure as for a normal list, but 
	 * with CBRACKET as the end condition instead of CPAREN */
	VyParseTree* list = ParseListGeneric(CBRACKET);

	/* Put it in an outer list containting quote-substitutions */
	VyParseTree* outerList = MakeListTree();
	VyParseTree* symb = MakeIdent();
	SetStrData(symb, "quote-substitutions");
	AddToList(outerList, symb);
	AddToList(outerList, list);

	return outerList;
}

/* Parse a list enclosed in {braces} as an infix list */
VyParseTree* ParseCurlyList(){
	VyParseTree* list = ParseListGeneric(CCURLY);

	/* Put it in an outer list containting quote-substitutions */
	VyParseTree* outerList = MakeListTree();
	VyParseTree* symb = MakeIdent();
	SetStrData(symb, "infix");
	AddToList(outerList, symb);
	AddToList(outerList, list);

	return outerList;
}

/* Parse an item preceeded by a quote mark ' */
VyParseTree* ParseQuoted(){
	/* Parse it normally and put it in a quote */
	return Quote(Parse());
}

/* Parse a substitution (an item preceeded by a dollar sign) */
VyParseTree* ParseSubstitution(){
	/* Parse the next item and  put it in a substitution node */
	return Substitution(Parse(), 0);
}

/* Parse a splicing subsitution */
VyParseTree* ParseSpliceSubstitution(){
	/* Parse the next item and  put it in a substitution node */
	return Substitution(Parse(), 1);
}

/* Parse a number from a token */
VyParseTree* ParseNumberFromToken(VyToken* tok){
	char* numData = tok->data;
	VyNumber** num = ParseNumber(numData);

	/* Check for errors in the parsing */
	char* error = GetLastNumberParsingError();
	if(error != NULL){
		return ParseError(error);	
	}

	/* If no errors, return the parsing result */
	else{
		VyParseTree* tree = MakeNum();
		SetNumberData(tree, num);
		return tree;
	}
}

/* Parse the next expression */
VyParseTree* Parse(){
	/* Check that we have not reached the end of the input stream; if so, return null */
	if(!MoreTokensExist()){
		return NULL;	
	}


	/* Get the next token */
	VyToken* next = GetNextToken();

	/* It's type is used to determine how to continue parsing */
	int tokType = next->type;

	/* Store the result of parsing before returning it */
	VyParseTree* expr;

	/* If it starts with a parenthesis, parse it as a list */
	if(tokType == OPAREN){
		expr =  ParseList();
	}

	/* If it begins with a quote, then parse whatever is next and quote it */
	else if(tokType == QUOTE){
		expr = ParseQuoted();
	}

	/* Parse a substitution */
	else if(tokType == DOLLAR){
		expr = ParseSubstitution();
	}
	/* Parse a splicing substitution */
	else if(tokType == DOLLARAT){
		expr = ParseSpliceSubstitution();	
	}

	/* Parse a bracketed list */
	else if(tokType == OBRACKET){
		expr = ParseBracketedList();
	}

	/* Parse an infix list (curly braces) */
	else if(tokType == OCURLY){
		expr = ParseCurlyList();	
	}
	/* If it is a number, identifier, or string then make a parse tree out of the token */
	else if(tokType == IDENT){
		VyParseTree* ident = MakeIdent();
		SetStrData(ident, next->data);
		expr = ident;
	}
	else if(tokType == NUM){
		expr = ParseNumberFromToken(next);
	}
	else if(tokType == STRING){
		VyParseTree* str = MakeString();
		SetStrData(str,next->data);
		expr = str;
	}
	/* Unexpected end of list */
	else if(tokType == CPAREN || tokType == CBRACKET || tokType == CCURLY){
		VyParseTree* err = ParseError("Unexpected end of list");
		SetPosition(err, next->pos);
		return err;
	}

	/* If there is no expression before a :, then the token type will be COLON
	 * Instead of dying, add an error */
	else if(tokType == COLON){
		VyParseTree* error = ParseError("Reference lacking instance");
		SetPosition(error, next->pos);  
		return error;
	}

	/* Handle object references: Check whether the next token is a colon.
	 * If so, then use the previously parsed expression (expr) and another
	 * expression  gotten from Parse() to create a reference node */
	VyToken* lookAhead = GetNextToken();
	if(lookAhead != NULL /* Make sure that the token list didn't end before looking at the type */
			&& lookAhead->type == COLON){ 
		VyParseTree* obj = expr;

		VyParseTree* ref = Parse();

		/* Check for validity */
		if(ref == NULL){
			expr = Reference(obj, ParseError("Incomplete reference."));  
		}else{
			expr = Reference(obj, ref);
		}
	}
	else{
		/* Backtrack one token to make up for the lookahead */
		if(lookAhead != NULL) BacktrackToken();
	}   

	/* Set the position of the current expression */
	SetPosition(expr, next->pos);

	/* If the tree is an object reference, set the position of 
	 * the first part (obj), because it wasn't gotten through a full Parse() call*/
	if(expr->type == TREE_REF){
		SetPosition(GetObj(expr), next->pos);
	}

	return expr;
}

/* Check and print errors  */
int CheckAndPrintErrors(VyParseTree* tree){
	int treeType = tree->type;
	int error = 0;

	if(treeType == TREE_LIST){
		/* Check each element recursively */
		int i;
		for(i = 0; i < ListTreeSize(tree); i++){	
			VyParseTree* next = GetListData(tree,i);

			/* Check the sub nodes for errors */
			int listError = CheckAndPrintErrors(next);
			if(listError) error = 1;
		}
	}

	/* Check each piece of the ref */
	else if(treeType == TREE_REF){

		int objError = CheckAndPrintErrors(GetObj(tree));
		int refError = CheckAndPrintErrors(GetRef(tree));
		if(objError || refError) error = 1;
	}

	/* If it is an error, print the error */
	else if(treeType == TREE_ERROR){
		printf("\n\n");
		printf("------- Parsing Error -------\n");
		printf("Position: ");
		PrintPosition(tree->pos);
		printf("\n");
		printf(tree->data->error.message);
		printf("\n-----------------------------");
		error = 1;
	}

	return error; 


}

/* Functions to print the tree */
int linesPrinted = 0;

/* Print a string multiple times */
void PrintMultiple(char* str, int times){
	int t;
	for(t = 0; t < times; t++){
		printf(str);
	}
}

void PrintParseTree(VyParseTree*);
void PrintListGeneric(VyParseTree* tree, char oDelim, char cDelim){
	printf("%c", oDelim);

	/* Print each element recursively */
	int i;
	for(i = 0; i < ListTreeSize(tree); i++){	
		VyParseTree* next = GetListData(tree,i);
		if(IsQuote(next)){
			printf("'");
			PrintParseTree(GetListData(next, 1));
		}
		else if(IsSubstitution(next)){
			if(IsSplicingSubstitution(next)){
				printf("$@");		
			}else{
				printf("$");	
			}

			PrintParseTree(GetListData(next, 1));
		}
		else if(next->type == TREE_LIST){
			VyParseTree* first = GetListData(next, 0);
			if(first->type == TREE_IDENT && StrEquals(GetStrData(first), "infix")){
				PrintListGeneric(GetListData(next, 1), '{','}');
			}
			else if(first->type == TREE_IDENT && StrEquals(GetStrData(first), "quote-substitutions")){
				PrintListGeneric(GetListData(next, 1), '[',']');
			}else{
				PrintParseTree(next);	
			}
		}
		else{
			PrintParseTree(next);
		}
	}

	/* If it wasn't an empty list, remove the extra space generated by the item inside */
	if(ListTreeSize(tree) > 0){
		printf("\b");
	}

	printf("%c ", cDelim);  
}

/* Recursively print a parse tree as code */
void PrintParseTree(VyParseTree* tree){
	int treeType = tree->type;

	/* If it is a list, then print a parenthesized list */
	if(treeType == TREE_LIST){
		PrintListGeneric(tree, '(', ')');
	}

	/* Print a reference separated by a colon */
	else if(treeType == TREE_REF){
		PrintParseTree(GetObj(tree));
		/* Delete the previous space before adding the colon */
		printf("\b:");
		PrintParseTree(GetRef(tree));
	}

	/* If it is a number or identifier, just print the string */
	else if(treeType == TREE_IDENT)  {
		printf("%s ", GetStrData(tree));
	}
	else if(treeType == TREE_NUM){
		PrintNumber(GetNumberData(tree));

		/* Print a space so that the backspace doesn't delete part of the number */
		printf(" ");
	}
	/* Print strings enclosed in quotes */
	else if(treeType == TREE_STR){
		printf("\"");
		printf("%s", GetStrData(tree));
		printf("\"");
		printf("\"");
	}

	/* If it is an error, print the error */
	else if(treeType == TREE_ERROR){
		printf("\n---------------------------------\n");
		printf("Error: %s", tree->data->error.message);
		printf("\n---------------------------------\n");
	}

	else{
		printf("\n\n\nWarning: Incorrect parse tree node type: %d! \n\n\n", treeType);		
	}

}

/* The controlling function for PrintParseTree(VyParseTree*)  */
void PrintTree(VyParseTree* tree){
	if(tree != NULL){
		printf("\n");

		/* Recursively print */
		PrintParseTree(tree);

		linesPrinted = 0;
	}else{
		printf(" NULL TREE ");	
	}
}

/* A utility function for parsing a whole file */
VyParseTree* ParseFile(char* filename){
	if(filename == NULL){
		fprintf(stderr, "Null pointer as filename.");
		return NULL;
	}

	/* Perform lexing */
	LexFile(filename);

	if(GetNumTokens() < 1){
		printf("Empty file: %s\n", filename);
		return NULL;
	}
	/* Parse the tokens */
	VyParseTree* list = MakeListTree();
	while(MoreTokensExist()) {
		VyParseTree* tree = Parse();
		AddToList(list, tree);
	}

	CleanLexer();

	return list;

}

/* Free all parser resources and restart the parser to it's original state */
void CleanParser(){
	linesPrinted = 0;
}

