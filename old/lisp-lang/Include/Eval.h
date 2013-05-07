#ifndef EVAL_H
#define EVAL_H

#include "Vyion.h"

/* The eval function is the basis of the interpreter. It actually
 * evaluates the parse tree and returns a value for it.
 */

/* Expand a of macro */
VyObject ExpandMacro(VyMacro**, VyParseTree*);

/* Evaluate an expression */
VyObject Eval(VyParseTree*);

/* Convert an object to a parse tree if possible */
VyParseTree* ObjToParseTree(VyObject);

/* Evaluate a quoted expression */
VyObject QuotedEval(VyParseTree*, int);

/* Handle an error */
void HandleError(VyObject);

int StrEquals(char*, char*);

#endif /* EVAL_H */
