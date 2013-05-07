#ifndef MACRO_H
#define MACRO_H

/* A macro is more or less a function on steroids. The difference between a macro and a function is this: a macro must return
 * a data type which can be then converted into a parse tree. These data types include lists, symbols, numbers, as well as others.
 * What makes a macro special as opposed to a function is that unlike a function, it doesn't generate a value - it generates code.
 * This code is then evaluated, and only that results in a value. 
 *
 * The data type that stores a macro is very similar to the one that stores a function, but since all macros must be native code, 
 * the data type does not need to store a pointer to a function. 
 */

/* The macro data type */
struct VyMacro {
	/* The number of arguments to the macro */
	int numArgs;	

	/* The arguments */
	Argument** args;

	/* The macro code */
	VyParseTree* code;

	/* The scope (macro closures) */
	Scope* scp;
};

/* Create a macro */
VyMacro** CreateMacro(Argument**, int, VyParseTree*, Scope*);

/* Evaluate a macro and return the resulting parse tree */
VyParseTree* EvalMacro(VyMacro**, VyObject*, int);

/* Parse a macro */
VyObject ParseMacro(VyParseTree*);

#endif /* MACRO_H */
