#include "Vyion.h"

/* Create an error from an expression and the message */
VyError** CreateError(char* message, VyParseTree* location){
	VyError** err = CreateErrorObj();	
	err[0]->message = message;
	err[0]->expr = location;

	return err;
}

/* Print an error */
void PrintError(VyError** err){
	printf("\n\n");
	printf("------- Error Occured -------");
	if(err[0]->expr != NULL){
		PrintTree(err[0]->expr);
		printf("\n");
		if(err[0]->expr->pos != NULL){
			printf("Position: ");
			PrintPosition(err[0]->expr->pos);
			printf("\n");
		}
	}
	else {
		printf("\n");	
	}
	printf(err[0]->message);
	printf("\n-----------------------------");
}
