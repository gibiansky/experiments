#include "Vyion.h"

/* Create a list */
VyList** CreateList(){
	/* Create a list struct and initialize its members to NULL */
	VyList** l = CreateListObj();
	l[0]->data = -1;
	l[0]->next = NULL;

	return l;
}

/* First element of the list */
VyObject ListHead(VyList** l){
	if(l != NULL){
		return l[0]->data;	
	}

	return -1;
}

/* List tail */
VyList** ListTail(VyList** l){
	if(l != NULL){
		return l[0]->next;	
	}

	return NULL;
}

/* Get from index */
VyObject ListGet(VyList** l, int index){
	if(l != NULL){
		/* If this one is it, return the data */
		if(index == 0){
			return l[0]->data;	
		}

		/* Otherwise, keep going */
		else{
			return ListGet(l[0]->next, index - 1);	
		}
	}

	return -1;
}

/* Clone a list */
VyList** CloneList(VyList** l){
	/* A base case for recursive list copying */
	if(l == NULL){
		return NULL;	
	}
	//printf("List data: (id %d) (ptr %p) (rptr %p) (next %p) (data %d)\n", ToObject(l), l, l[0], l[0]->next, l[0]->data);fflush(stdout);

	VyList** new = CreateList();
	new[0]->data = l[0]->data;
	new[0]->next = CloneList(l[0]->next);

	return new;
}

/* Internal function used in ListAppend() to avoid side effects */
void ListInternalAppend(VyList** l, VyObject v){
	/* Check to see whether this is an empty list */
	if(l[0]->data < 0){
		/* If it is, then set its data instead of creating a new node */
		l[0]->data = v;
		return;
	}

	/* If this is the last node, add the value to a new node */
	if(l[0]->next == NULL){
		VyList** x = CreateList();
		l[0]->next = x;
		l[0]->next[0]->data = v;
	}

	/* Otherise, proceed to the last node */
	else{
		/* Use ListInternapAppend because here, we want it to have the 'side-effect' of actually adding something to the list */
		ListInternalAppend(l[0]->next, v);	
	}
}

/* Append an element to a list */
VyList** ListAppend(VyList** l, VyObject v){
	VyList** new = CloneList(l);
	ListInternalAppend(new, v);

	return new;
}

/* Find the size of a list */
int ListSize(VyList** l){
	/* Check for empty list */
	if(l[0]->next == NULL && l[0]->data < 0){
		return 0;	
	}

	/* If it isn't empty, recursively compute the size */
	if(l[0]->next == NULL){
		return 1;	
	}else{
		return ListSize(l[0]->next) + 1;	
	}
}

/* Get the list starting at an index */
VyList** GetListStartingAt(VyList** l, int index){
	if(l != NULL){
		/* If this one is it, return the data */
		if(index == 0){
			return l;	
		}

		/* Otherwise, keep going */
		else{
			return GetListStartingAt(l[0]->next, index - 1);	
		}
	}

	/* If l == NULL, return NULL */
	return NULL;
}

/* Insert an element into a list at an index */
VyList** ListInsert(VyList** l, VyObject v, int index){

	/* Copy the list to avoid side effects */
	l = CloneList(l);

	/* Create the new list element */
	VyList** newList = CreateList();
	newList[0]->data = v;

	/* It it is being added to the front, just add it to the front */
	if(index == 0){
		newList[0]->next = l;
		return newList;	
	}

	/* Else, Insert it into its place */
	VyList** prevNode = GetListStartingAt(l, index - 1);
	VyList** nextNode = GetListStartingAt(l, index);
	prevNode[0]->next = newList;
	newList[0]->next = nextNode;

	return l;
}

/* Concatenate two lists (make sure to copy the lists so that this call has no side effects) */
VyList** ListConcat(VyList** one, VyList** two){
	/* Find the last node of list one */
	VyList** oneCopy = CloneList(one);
	VyList** node = GetListStartingAt(oneCopy, ListSize(oneCopy));

	/* Set the next one to be the start of list two */
	node[0]->next = CloneList(two);

	return oneCopy;
}

/* Delete the list (but not the values) */
void DeleteList(VyList** l){
	if(l[0]->next != NULL){
		DeleteList(l[0]->next);
		free(l[0]->next);	
	}

	free(l);
}

/* Print a list */
void PrintList(VyList** l){
	int listSize = ListSize(l);
	int i;

	printf("(");

	/* Cycle through and print each value */
	for(i = 0; i < listSize;i++){
		VyObject next = ListGet(l, i);
		PrintObj(next);	
		printf(" ");
	}

	/* Delete the extra space if needed */
	if(listSize > 0){
		printf("\b");	
	}
	printf(")");
}
