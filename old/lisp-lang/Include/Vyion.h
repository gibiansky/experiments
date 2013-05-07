#ifndef VYION_HEADER_H
#define VYION_HEADER_H

/****** Include all the Vambre language headers ******/

/* Include all standard C libraries */
#include <stdio.h>
#include <malloc.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* Check that NULL is defined */
#ifndef NULL
	#define NULL 0
#endif

/* Include all the type definitions and declarations */
#include "Declarations.h"

/* The lexer and related utilities:
 *     The lexer takes either a string or a filename and then tokenizes that. 
 *     Tokenizing the input is the process of reading the input and splitting it up into
 *     pieces that will be easier for subsequent parsing. The token data structure is described in Token.h, 
 *     the different token types are described in TokenType.h, and the main lexing routines are described in Lexer.h. 
 */

#include "StringUtil.h"
#include "CharList.h"
#include "Token.h"
#include "Lexer.h"


/* Parser:
 *     The parser takes as an input a series of tokens, created by the lexer. It then reads through them
 *     and creates a parse tree based on them. The parse tree represents the structure of the program
 *     code. In the case of Vambre, the parse tree is just a list which may contain symbols, numbers, other lists, etc.
 *     The data structure to hold the parse tree is described in ParseTree.h, and the different types of parse trees 
 *     have an enumeration in TreeType.h.
 *     
 *     Note: For convenience, Parser.h also includes a routine to parse the contents of a file. This routine simply calls the lexing routine, and
 *     only then actually does the parsing.
 */

#include "Parser.h"
#include "ParseTree.h"

/* Evaluation of expressions:
 *     The function which evaluates a parse tree is the eval function, which is in Eval.h. The eval function
 *     takes a parse tree structure and then evaluates it (recursively, if needed). Functions are described in Function.h, which presents 
 *     a function data type that unifies built-in C functions and functions actually written in Vambre through the use of function pointers. 
 *     Vambre is lexically scoped, and the scope data structure in described in Scope.h, while the call stack is in ScopeStack.h. 
 *     The different types of objects and values are unified into one type in Value.h, with the value type enumeration in ValueType.h. 
 *     Variables, that is, bindings to values, are described in Value.h.
 *
 *     Note: The main entry point to the program is in the Eval() function, in Eval.h.
 */

#include "Eval.h"
#include "Scope.h"
#include "ScopeStack.h"
#include "Object.h"
#include "Variable.h"

/* Basic variable types:
 *    The different types of objects in Vambre are described in these files. Currently, Vambre has the following types:
 *        - Boolean: 	True or false values, used in boolean expressions.
 *        - List:	A list of objects, implemented as a linked list.
 *        - Number:	A number, which can be either real (i.e. double), integer, or complex. Arithmetic operations convert between those types.
 *        - Symbol:	The symbol is what you get as a result of quoting an identifier. It is (more-or-less) a string used as an identifier.
 *        - Function:	A function, which can be called with arguments to produce a result. Functions are created with lambda.
 *        - Macro: A macro, which evaluates to Vambre code, which can then be used for anything else. Created with mambda.
 *        - Error: An error. Errors contain information for traceback calls. Note, these aren't errors that you can resume from, only catch.
 */

#include "Boolean.h"
#include "List.h"
#include "Number.h"
#include "Symbol.h"
#include "Function.h"
#include "Macro.h"
#include "Error.h"
#include "FlowControl.h"

/* Memory management:
 * These headers provide an interface to the Vambre memory functions, which allocate and free memory,
 * as well as the Vambre garbage collector.
 */
#include "Mem.h"

/* Various type enumerations */
#include "TokenType.h"
#include "TreeType.h"
#include "ObjType.h"
#include "NumberType.h"

#endif /* VAMBRE_HEADER_H */
