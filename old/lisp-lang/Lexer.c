#include "Vyion.h"

/* The resulting tokens */
VyToken** tokenList = NULL;
int numTokens = 0;
int currentToken = 0; //For returning the tokens one by one

/* The special characters */
const char specialChars[] = { '(', ')', '[', ']', '{', '}', ':', '$', '\''};

/* Read the contents of a file */
char* ReadFile(char* filename){
	/* Open that file for reading and make sure it is accessable */
	FILE* file = fopen(filename, "r");
	if(file == NULL){
		fprintf(stderr, "\"%s\" not available.\n", filename);
		exit(0);
	}

	/* Find the size of the file */
	fseek(file, 0, SEEK_END);
	int length = ftell(file);

	/* Return to the beginning of the file for reading */
	fseek(file, 0, SEEK_SET);	

	/* Read the contents of the file */
	int size = sizeof(char)*(length);

	/* Add one to the memory needed for the extra '\0' character */
	char* contents = malloc(size + 1);
	if(contents == NULL){		
		fprintf(stderr, "Memory error\n");
		return 0;
	}
	fread(contents, size, 1, file);
	fclose(file);

	/* Add the terminating 0 to the string */
	contents[size] = '\0';

	return contents;
}

/* Anything non-whitespace and not a special character returns true */
int isIdentChar(char c){
	/* Check that it isn't whitespace or a special character */
	if(isWhitespace(c) == 1) return 0;
	int i;
	for( i = 0; i < 9; i++){
		if(c == specialChars[i]) return 0;
	}

	return 1;
}

/* Decide whether a string is a number or an identifier */
int isNumber(CharList* str){
	char first = Get(str, 0);

	/* A string is a number if:
	 *  - the first character is a number
	 *  - the first character is a '+', '-', or '.', and:
	 *	  * is followed by a sequence of numbers 
	 *	  * or is followed by a  sequence of numbers with 'e' or '.' in it, but not as the second or last characters
	 *	  * also, 'e' and '.' cannot be repeated twice in a number
	 */

	/* It is a number if the first character is a number */
	if(isNumeric(first)){
		return 1;
	}
	/* It can also be a number if the first character is  '+', '-', or '.' (but only if there are more characters later)  */
	else if((first == '-' || first == '+' || first == '.') && Size(str) > 1){
		/* The rest must be either numeric or 'e' 
		 * 'e' can only occur once, and cannot be second or last */
		int occurences_of_e = 0;
		int i;
		for(i = 1; i < Size(str); i++){
			/* Deal with the 'e' case */
			if(Get(str, i) == 'e'){
				/* In a number, it cannot be second or last */
				if(i == 1 || i == (Size(str) - 1) || occurences_of_e > 0){
					return 0;   //If it is, then it's not a number, therefore return false
				}
				occurences_of_e++;
			}
			/* Make sure '.' isn't repeated twice */
			else if(Get(str,i) == '.'){
				if(first == '.'){
					return 0;
				}
			}
			/* Also, if it ends with i then it is an imaginary number */
			else if(Get(str,i) == 'i' || Get(str,i) == 'I'){
				/* If it isn't one, then it is an error and it cannot be a number */
				if(i != Size(str) - 1) {
					return 0;
				}
			}
			/* If any character is non-numeric, not 'e', and not '.', then it can't be a number */
			else if(!isNumeric(Get(str,i))){
				return 0;
			}
		}

		/* If it hasn't failed yet, its a number */
		return 1;
	}
	/* Otherwise, it is an ident */
	else{
		return 0;
	}

}

/* Add a new token with a position */
void AddToken(VyToken* tok, int line, int character, int indent){
	/* Set the position */
	SetTokenPosition(tok, line, character, indent);

	/* Make more room and add it to the array */
	numTokens++;
	tokenList = realloc(tokenList, (numTokens)*sizeof(VyToken*));
	tokenList[numTokens - 1] = tok;
}

/* Convert a token type int to a string */
char* GetTokenTypeStr(VyToken* tok){
	int type = tok->type;
	switch(type){
		case 0: return "O-Paren  ";
		case 1: return "C-Paren  ";
		case 2: return "O-Bracket";
		case 3: return "C-Bracket";
		case 4: return "Colon	 ";
		case 5: return "Dollar   ";
		case 6: return "Quote	 ";
		case 7: return "Number   ";
		case 8: return "Ident    ";
		case 9: return "String   ";
		case 10:return "Dollar-At";
		case 11:return "O-Curly  ";
		case 12:return "C-Curly  ";
		default:return "Unknown token type.... ";
	}
}

/* Get the data from a token in text form for printing */
char* GetTokenDataStr(VyToken* tok){
	int type = tok->type;
	switch(type){
		case 0: return "(";
		case 1: return ")";
		case 2: return "[";
		case 3: return "]";
		case 4: return ":";
		case 5: return "$";
		case 6: return "'";
		default: return tok->data;
	}
}   

/* Print a token in a pretty manner */
void PrintToken(VyToken* tok){
	printf("\nToken Type: %s\t", GetTokenTypeStr(tok));
	if(HasKnownPosition(tok)){
		printf("at position:(%d, %d, %d)\t", GetLine(tok), GetCharacter(tok), GetIndent(tok));
	}
	printf(" with data: %s", GetTokenDataStr(tok));


}

/* Print the tokens in a pretty fashion for debugging */
void PrintTokenList(){
	int i;
	for(i = 0; i < numTokens; i++){
		VyToken* tok = tokenList[i];
		PrintToken(tok);
	}
}

/* Clean-up functions */
void DeleteTokenList(){
	/* Free each token individually */
	int t;
	for(t = 0; t < numTokens; t++){
		DeleteToken(tokenList[t]);
	}

	/* Free the token list itself */
	free(tokenList);
	tokenList = NULL;
}

/* Clean up so the lexer can be reused */
void CleanLexer(){
	DeleteTokenList();
	numTokens = 0;
	currentToken = 0;
}

/* Perform lexing on the given text */
void Lex(char* text){
	/* Keep track of the amount processed */
	int length = strlen(text);
	int read = 0;   

	/* Keep track of the current position in the file */
	int line = 0;
	int charOnLine = 0;
	int indent = 0;

	/* Process all the text until the ASCII 0 character */
	while(read < length){
		/* Read next character */
		char next = text[read];
		read++;

		/* Use newlines and spaces for position */
		if(isWhitespace(next)){
			if(next == '\n'){
				line++;
				indent = 0;
				charOnLine = 0;
			}else{
				if(next == '\t'){
					indent++;
				}
				charOnLine++;
			}

		}

		/* Recognize all the special characters */
		else if(next == '('){
			AddToken(EmptyToken(OPAREN), line, charOnLine, indent); 
			charOnLine++;
		}
		else if(next == ')'){
			AddToken(EmptyToken(CPAREN), line, charOnLine, indent); 
			charOnLine++;
		}
		else if(next == '['){
			AddToken(EmptyToken(OBRACKET), line, charOnLine, indent); 
			charOnLine++;
		}
		else if(next == ']'){
			AddToken(EmptyToken(CBRACKET), line, charOnLine, indent); 
			charOnLine++;
		}
		else if(next == ':'){
			AddToken(EmptyToken(COLON), line, charOnLine, indent); 
			charOnLine++;
		}
		else if(next == '$'){
			/* Check if it is a splice substitution */
			if(text[read] == '@'){
				AddToken(EmptyToken(DOLLARAT), line, charOnLine, indent);	
				charOnLine++;
				read++;
			}else{
				AddToken(EmptyToken(DOLLAR), line, charOnLine, indent);
			}

			charOnLine++;
		}
		else if(next == '\''){
			AddToken(EmptyToken(QUOTE), line, charOnLine, indent);
			charOnLine++;
		}
		else if(next == '{'){
			AddToken(EmptyToken(OCURLY), line, charOnLine, indent);
			charOnLine++;
		}
		else if(next == '}'){
			AddToken(EmptyToken(CCURLY), line, charOnLine, indent);
			charOnLine++;
		}

		/* Completely ignore comments */
		else if(next == '|' && text[read] == '{'){
			/* Comments start with |{ and end with }|, nested comments allowed */
			charOnLine += 2;
			read ++;
			int commentLevel = 1;
			next = text[read];
			read++;

			while(commentLevel > 0){
				if(next == '}' && text[read] == '|'){
					commentLevel--;
				}
				else if(next == '|' && text[read] == '{'){
					commentLevel++;

				}
				else if(next == '\0'){
					printf("Unclosed comment at end of program. Exiting.");
					exit(0);
				}
				else if(next == '\n'){
					line++;
					charOnLine = 0;
					indent = 0;
				}
				else if(next == '\t'){
					indent++;
				}

				charOnLine++;
				next = text[read];
				read++;
				
			}
		}
		else if(next == ';'){
			/* For single line comments starting with a semicolon, just keep reading until the \n */
			while(next != '\n' && next != '\0'){
				next = text[read];
				read++;
			}

			/* And increment the line count */
			line++;
			indent = 0;
			charOnLine = 0;
		}
		else if(next == '#'){
			/* Loop through until the end of the ident */
			while(1){
				if(!isIdentChar(text[read])){
					break;	
				}

				next = text[read];
				read++;

				/* Position */
				if(next == '\n'){
					line++;
					indent = 0;
					charOnLine = 0;
				}else{
					charOnLine++;
				}
			}
		}

		/* Record strings enclosed in "quotes" separately */
		else if(next == '"'){
			/* Record the 'previous' character and keep reading until you have a quote not preceeded by a backslash */
			CharList* str_contents = MakeCharList();

			char prev = next;
			next = text[read];
			read++;
			charOnLine++;

			/* Record the starting position */
			int start_line = line;
			int start_char = charOnLine;

			while(next != '"' || prev == '\\'){
				Add(str_contents, next);
				prev = next;
				next = text[read];
				read++;

				/* Position */
				if(next == '\n'){
					line++;
					indent = 0;
					charOnLine = 0;
				}else{
					charOnLine++;
				}

			}

			/* Add the string token and clean up */
			AddToken(DataToken(STRING, ToStr(str_contents)), start_line, start_char, indent);
			Delete(str_contents);

		}
		/* Lastly, deal with numbers and identifiers */
		else {

			/* Find the whole string */
			CharList* ident = MakeCharList();
			while(isIdentChar(next) && next != '\0'){  //While the character can be in a number or identifier, keep reading
				Add(ident, next);
				next = text[read];
				read++;
				charOnLine++;
			}

			/* Don't skip the character after the ident, it may be a symbol and not a space */
			read--;

			/* Convert the character list to a string */
			char* ident_string = ToStr(ident);
		
			/* Decide whether the string is a number or identifier token and add it */
			if(isNumber(ident)){
				AddToken(DataToken(NUM, ident_string), line, charOnLine, indent);
			}else{
				AddToken(DataToken(IDENT, ident_string), line, charOnLine, indent);
			}

			/* The string is no longer needed, so delete it */
			Delete(ident);
		}
	}

}

/* A utility function for reading and lexing a whole file */
void LexFile(char* filename){
	/* Read the file and perform lexing */
	char* fileContents = ReadFile(filename);
	Lex(fileContents);

	/* Free the memory used by the file contents */
	free(fileContents);

}

/* Functions to access the token list */
VyToken** GetTokenList(){
	return tokenList;
}

/* Backtrack one token */
int BacktrackToken(){
	currentToken--;

	return currentToken;
}

/* Return the next token */
VyToken* GetNextToken(){
	/* Make sure there are more tokens; if not, return NULL */
	if(currentToken >= numTokens){
		return NULL;
	}else{
		VyToken* next = tokenList[currentToken];
		currentToken++; //Increment the index of the current token
		return next;
	}
}

/* Return a lookahead token */
VyToken* GetLookAheadToken(){
	VyToken* next = GetNextToken();

	/* Only backtrack if a token really was returned */
	if(next != NULL) BacktrackToken();

	return next;
}

/* Whether more tokens exist */
int MoreTokensExist(){
	if(currentToken >= numTokens){
		return 0;
	}else{
		return 1;
	}
}

/* Find the number of tokens */
int GetNumTokens(){
	return numTokens;
}

