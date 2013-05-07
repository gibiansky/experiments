#ifndef ERROR_H
#define ERROR_H

#include "Vyion.h"

/* An error with the message and the expression itself (from which the position may be deduced) */
struct VyError {
	char* message;		
	VyParseTree* expr;
};

/* Create an error object */
VyError** CreateError(char*, VyParseTree*);

/* Print an error */
void PrintError(VyError**);

#endif /* ERROR_H */
