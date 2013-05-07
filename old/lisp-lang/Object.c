#include "Vyion.h"

/* This is the implementation of generic objects. 
 *
 * VyObjects are not actually objects - instead, they are just the ID's of objects. (You can verify this by looking at Declarations.h.)
 * The actual object data is stored on the memory heap. The memory heap structure contains an array which links the object id's 
 * as the indices of the array to the object type and the object data. (See Mem.h, too)
 *
 * To find the actual locations of the object, the interpreter maintains an array, each slot corresponding to one object. 
 * If the index of a slow is an object's ID, then the data stored there is the actual location of the object. Thus, 
 * when the garbage collector is trigerred, all it needs to do is update that array. (The array is added to by CreateObj(), 
 * with one new slot used for every new object. )
 *
 * To get the actual data from an object, use the ObjData() function, and to get the type, use the ObjType() function. Both of them
 * use the array to look up - well, actually, it isn't look up since its just one array access - but anyway, they use the array
 * to find the location of the object on the heap, and then use that to find the type and data.
 *
 * Often, you will find yourself with a VyFunction**, or VyNumber**, etc etc, and you need to find the ID of that object. To do this,
 * use the ToObject() function. The ID of an object is stored in the contiguous memory BEFORE an object as an integer, so the ToObject()
 * function just finds this location and retrieves the ID from it. 
 *
 * *Note: 'virtually' isn't really true. It happens when the heap runs out of memory - however, there's now way of
 * predicting this, really, so manipulating any objects in the same function as creating them would be unsafe.
 */

/***** Create objects *****/

/* The heap on which all these objects are stored */
VyMemHeap* heap = NULL;

void SetMemoryHeap(VyMemHeap* memHeap){
	heap = memHeap;	
}
VyMemHeap* GetMemoryHeap(){
	return heap;	
}

/* Find the size (in bytes) taken up by the actual data behind an object for a certain type */
	int typeSizes[] = {
		sizeof(VyNumber),
		sizeof(VyFunction),
		sizeof(VyList),
		sizeof(VySymbol),
		sizeof(VyBoolean),
		sizeof(VyMacro),
		sizeof(VyError),
		sizeof(VyFlowControl)
	};
int DataSize(int type){
	return typeSizes[type];
}

/* Allocate memory for an object of a certain type, and return the ID of the object  */
VyObject CreateObj(int type){
	/* Mallocate room */
	void* mem = VyMallocate(DataSize(type) + sizeof(int), heap);

	/* The object Id is just the number of the object on the heap */
	int objId = heap->objectsOnHeap;

	/* If needed, add space in the arrays */
	int objIndex = objId % heap->idMapSize;
	if(objIndex == 0){
		/* Increase the number of ID maps and allocate space for everything */
		heap->numIdMaps++;
		heap->idMapArray = realloc(heap->idMapArray, sizeof(void***) * heap->numIdMaps);
		heap->idMapArray[heap->numIdMaps - 1] = malloc(sizeof(void**) * 2);
		heap->idMapArray[heap->numIdMaps - 1][0] = malloc(sizeof(void*) * heap->idMapSize);
		heap->idMapArray[heap->numIdMaps - 1][1] = malloc(sizeof(void*) * heap->idMapSize);
	}

	/* The location of the object in the arrays */

	heap->idMapArray[heap->numIdMaps - 1][0][objIndex] = (void*)(type);
	heap->idMapArray[heap->numIdMaps - 1][1][objIndex] = mem + sizeof(int);

	/* Store the id of the object right before the object itself for efficiency */
	*(int*)(mem) = objId;
	heap->objectsOnHeap++;

	/* Return the ID */
	return objId;
}

/* Create objects */
VyBoolean** CreateBoolObj(){
	return ObjData(CreateObj(VALBOOL));	
}
VyNumber** CreateNumObj(){
	return ObjData(CreateObj(VALNUM));	
}
VyFunction** CreateFuncObj(){
	VyFunction** f = ObjData(CreateObj(VALFUNC));
	return f;
}
VyMacro** CreateMacroObj(){
	return ObjData(CreateObj(VALMAC));	
}
VyList** CreateListObj(){
	return ObjData(CreateObj(VALLIST));	
}
VySymbol** CreateSymbObj(){
	return ObjData(CreateObj(VALSYMB));	
}
VyError** CreateErrorObj(){
	return ObjData(CreateObj(VALERROR));
}
VyFlowControl** CreateFlowControlObj(){
	return ObjData(CreateObj(VALFLOW));
}

/***** Retrieve data from VyObject pointers *****/

void* ObjData(VyObject val){
	int idMapNum = val/heap->idMapSize;
	int objIndex = val % heap->idMapSize;
	return &(heap->idMapArray[idMapNum][1][objIndex]);
}
int ObjType(VyObject val){
	int idMapNum = val/heap->idMapSize;
	int objIndex = val % heap->idMapSize;
	return (int)(heap->idMapArray[idMapNum][0][objIndex]);
}

/* Retrieve the object ID from a VyNumber**, VyFunction**, VyList**, etc */
VyObject ToObject(void* doublePointer){
	/* Get the pointer to the ID of this object */
	void** ptr = (void**)(doublePointer);
	int* idPtr = (int*)((char*)(*ptr) - sizeof(int));
	return *idPtr;
}

/* Print a value */
void PrintObj(VyObject val){
	if(ObjType(val) == VALNUM){
		PrintNumber(ObjData(val));	
	}

	else if(ObjType(val) == VALLIST){
		PrintList(ObjData(val));	
	}

	else if(ObjType(val) == VALSYMB){
		PrintSymbol(ObjData(val));	
	}

	else if(ObjType(val) == VALBOOL){
		PrintBoolean(ObjData(val));		
	}

	else if(ObjType(val) == VALERROR){
		PrintError(ObjData(val));	
	}

}
