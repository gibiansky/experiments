#ifndef LIST_H
#define LIST_H

#include "Vyion.h"

/* A list is one of Vyion's basic data types, since its whole 
 * code structure is based on lists. Although traditionally Lisp
 * lists are stored as linked lists, there is really no such restriction
 * as long as the list implements head, tail, get, size, append, etc etc.
 * Therefore, the implementation of this may change.
 */

/* A linked list data structure */
struct VyList {
	VyList** next;
	VyObject data;
};

/* Create a list */
VyList** CreateList();

/* Copy a list */
VyList** CloneList(VyList**);

/* First element of the list */
VyObject ListHead(VyList**);

/* List tail */
VyList** ListTail(VyList**);

/* Find the size of a list */
int ListSize(VyList**);

/* Get from index */
VyObject ListGet(VyList**, int);

/* Append an element to a list */
VyList** ListAppend(VyList**, VyObject);

/* Insert an element into a list at an index */
VyList** ListInsert(VyList**, VyObject, int);

/* Concatenate two lists */
VyList** ListConcat(VyList**, VyList**);

/* Delete the list */
void DeleteList(VyList**);

/* Print a list */
void PrintList(VyList**);

#endif /* LIST_H */
