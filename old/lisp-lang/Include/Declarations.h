#ifndef DECLARATIONS_H
#define DECLARATIONS_H

/* This file is just a list of all the typedef's. 
 * It can also serve as a sort of 'index' for all 
 * the data structures in the interpreter. All the
 * structs are in the same named files, except for
 * VyObject, VyParseTree, and VyToken, which are in 
 * Object.h, ParseTree.h, and Token.h, respectively 
 */

/* Objects are represented by their integer ID's */
typedef 	int		 VyObject	;

/* Typdef all the structs */

typedef struct VyBoolean	 VyBoolean	;
typedef struct VyFunction	 VyFunction	;
typedef struct VyNumber		 VyNumber	;
typedef struct VyError		 VyError	;
typedef struct VyFlowControl	 VyFlowControl	;
typedef struct VyList		 VyList		;
typedef struct VySymbol		 VySymbol	;
typedef struct VyMacro		 VyMacro	;

typedef struct VyToken		 VyToken	;
typedef struct VyParseTree	 VyParseTree	;

typedef struct Scope		 Scope		;
typedef struct VarBinding	 VarBinding	;
typedef struct ScopeStack	 ScopeStack	;
typedef struct Argument		 Argument	;

typedef struct VyMemHeap 	 VyMemHeap	;

typedef struct Position		 Position	;
typedef struct CharList		 CharList	;

#endif /* DECLARATIONS_H */
