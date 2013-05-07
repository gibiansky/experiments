#ifndef STRING_UTIL_H
#define STRING_UTIL_H

/* A few string and character functions which are used extensively throughout the interpreter.
 * Mostly, however, their uses are confined to the lexer and number parsing routines.
 */

/* Checks whether the character represents a digit (i.e., matches [0-9]) */
int isNumeric(char);

/* Checks whether a character is whitespace (space, tab, or newline) */
int isWhitespace(char);

/* Safely concat two strings, with no side effects, although the newly created string should still be freed explicitly. */
char* ConcatStrings(char*, char*);

#endif /* STRING_UTIL_H */
