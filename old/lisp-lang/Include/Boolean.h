#ifndef BOOLEAN_H
#define BOOLEAN_H

#include "Vyion.h"

/* Booleans should be pretty simple. A boolean value is just a true or false value.
 * Booleans are used in things such as if statements - the condition MUST evaluate
 * to a boolean. Unlike other Lisps, Vyion doesn't have a NIL variable which is considered false.
 * The only two boolean things are true and false, which, in the interpreter, are 
 * held in the true! and false! global variables. 
 */

/* A boolean type, 0 for false, and anything else for true */
struct VyBoolean {
	short torf;	
};

/* Check the truth value of a boolean */
int IsTrue(VyBoolean**);
int IsFalse(VyBoolean**);

/* Creating booleans */
VyBoolean** MakeTrueBool();
VyBoolean** MakeFalseBool();

/* Functions for non-short-circuiting boolean operations */
VyBoolean** BoolAnd(VyBoolean**, VyBoolean**);
VyBoolean** BoolOr(VyBoolean**, VyBoolean**);
VyBoolean** BoolXor(VyBoolean**, VyBoolean**);
VyBoolean** BoolNot(VyBoolean**);

/* Functions for comparing numbers, which return a boolean */
VyBoolean** LessThan(VyNumber**, VyNumber**);
VyBoolean** GreaterThan(VyNumber**, VyNumber**);

VyBoolean** LessThanOrEqual(VyNumber**, VyNumber**);
VyBoolean** GreaterThanOrEqual(VyNumber**, VyNumber**);

VyBoolean** Equal(VyNumber**, VyNumber**);
VyBoolean** NotEqual(VyNumber**, VyNumber**);

/* Print a boolean as either true! or false! */
void PrintBoolean(VyBoolean**);


#endif /* BOOLEAN_H */
