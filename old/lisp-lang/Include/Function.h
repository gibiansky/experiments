#ifndef FUNCTION_H
#define FUNCTION_H

#include "Vyion.h"

/* A function is, unlike in some languages, also a basic type. A function can either be a
 * built-in function which is coded in another compiled language, like C, or it can be a
 * function written in Vyion. The function struct contains a pointer to a C function, which can either
 * be the evaluation function for a parse tree, or a built-in compiled function. This allows 
 * the interface to builtin and native (native meaning written in Vyion) functions to be the same.
 *
 * Arguments can be optional, named, and rest arguments. Also, a combination of named and optional arguments
 * is possible. The argument type enumeration is defined here, as is the Argument data structure. Functions
 * can do argument checking, and native functions do so anyway.
 */

/* Define types of arguments */
#define ARGOPTIONAL		1
#define ARGNAMED		2
#define ARGNAMEDOPTIONAL	3
#define ARGREST	 		4

/* A function argument */
struct Argument {
	/* The argument type */
	int argCode;	

	/* The symbol name (named arguments assume the same name) */
	char* name;

	/* Optional argument's default value, or NULL */
	VyObject optArgDefault;

	/* Argument value type */
	int type;

};

/* A function with its charactertics */
struct VyFunction {
	/* Function arguments */
	Argument** args;

	/* The number of arguments */
	int numArgs;

	/* Function pointer to a function used to process these arguments */
	/* The two arguments to EvalFunction are the function's arguments and the number of arguments */
	/* It returns the result of evaluating the function */
	VyObject  (* EvalFunction ) (struct VyFunction**, VyObject*, int);

	/* The following applies only to non-builtin functions. It is NULL for builtins. */

	/* Function code */
	VyParseTree* code;

	/* The function scope (for closures) */
	Scope* scp;

};

/* Create a built-in function */
VyFunction** CreateBuiltinFunction(Argument**, int, VyObject (*EvalFunction)(VyFunction**, VyObject*,int));

/* Create a native function */
VyFunction** CreateNativeFunction( Argument**, int, VyParseTree*, Scope*);

/* Create a function argument */
Argument* CreateArgument(int, char*, int);

/* Set a function's name */
void SetFunctionName(VyFunction**, char*);

/* Set a function's scope */
void SetFunctionScope(VyFunction**, Scope*);

/* Evaluate a function (pass the arguments and the number of them) */
VyObject RunFunction(VyFunction**, VyObject*, int);

/* Evaluate native and builtin functions */
VyObject EvalNativeFunction(VyFunction**, VyObject*, int);
VyObject EvalBuiltinFunction(VyFunction**, VyObject*, int);
VyObject EvalNativeFunctionOrMacro(Argument**, int, VyParseTree*, Scope*, VyObject*, int);

/* Parse a function's arguments */
Argument** ParseFunctionArguments(VyParseTree*, int*, char**);

/* Check the arguments for validity */
char* CheckFunctionArguments(Argument**, int, VyObject*, int);

/* Parse a function from a lambda expression */
VyObject ParseFunction(VyParseTree*);

/* Add a function to the function list */
void AddFunction(char*, VyFunction**);

/* Functions for checking argument types (named, optional, rest) */
int IsNamedArg(Argument*);
int IsRestArg(Argument*);
int IsOptionalArg(Argument*);

#endif /* FUNCTION_H */
