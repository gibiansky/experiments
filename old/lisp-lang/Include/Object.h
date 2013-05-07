#ifndef VyObject_H
#define VyObject_H

/* An object is the value returned by any operation or function in the Vyion language. Internally, 
 * you do not actually manipulate objects themselves. Instead - you manipulate their ID's, or the data inside them.
 * To look up the type of an object or the data of an object based on ID, use the ObjType() and ObjData() functions.
 */

#include "Vyion.h"

/* The memory heap */
void SetMemoryHeap(VyMemHeap*);
VyMemHeap* GetMemoryHeap();

/* Find the number of bytes needed for a certain type of object */
int DataSize(int);

/* Print a value to standard output */
void PrintObj(VyObject);

/* Create objects from values */
VyNumber** CreateNumObj();
VyFunction** CreateFuncObj();
VyMacro** CreateMacroObj();
VySymbol** CreateSymbObj();
VyList** CreateListObj();
VyBoolean** CreateBoolObj();
VyError** CreateErrorObj();
VyFlowControl** CreateFlowControlObj();

/* Retrieve the actual value and type from the contiguous memory space */
void* ObjData(VyObject);
int   ObjType(VyObject);

/* Convert a VyNumber*, VyFunction*, VyList*, etc to a VyObject */
VyObject ToObject(void*);

#endif /* VyObject_H */
