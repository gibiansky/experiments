#include "Vyion.h"

/* Whether a char is [0-9] */
int isNumeric(char c){
	if(c >= '0' && c <= '9') return 1;
	else return 0;
}

/* Whehter a char is a space, tab, or newline */
int isWhitespace(char c){
	if(c == ' ' || c == '\t' || c == '\n' || c == '\r') 
		return 1;
	else 
		return 0;
}

/* Concat strings */
char* ConcatStrings(char* str1, char* str2){
	/* Create a new string with a needed length */
	int totalLength = strlen(str1) + strlen(str2);
	char* new = calloc((totalLength+1),sizeof(char));

	/* Concat the strings */
	strcat(new, str1);
	strcat(new, str2);
	return new;
}


