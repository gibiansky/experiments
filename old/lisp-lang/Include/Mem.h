#ifndef V_MEMORY_H
#define V_MEMORY_H

#include "Vyion.h"

/* The memory manager, also known as the garbage collector, manages all the memory for the language */


/* The garbage collector operates on the memory heap, which is defined in the VyMemHeap struct. It 
 * contains data about the current heap size, the amount of space used on the heap, the start of the free
 * memory on the heap, and a pointer to the base of the heap. 
 * --------------------------------------------------------------------------------------------------------
 *
 * Also, it contains a 2-D array. The indices of the array are the ID numbers of the objects. The first row
 * of the array contains the type of the object (an integer), and the second row contains pointers to
 * the data of the objects. To facilitate use by the garbage collector, the interpreter should NEVER
 * directly store the value of that pointer in a variable, because the pointer may be invalidated during garbage
 * collection, resulting in a dangling pointer. Instead, the interpreter should use a pointer to that pointer, so that
 * when the garbage collector is called, it can update all the pointers and all the interpreter references will 
 * automatically be updated.
 *
 * Problem: When the amount of objects grows, the 2-D array must also grow. When, however, it is realloc'd, it may move
 * in memory, therefore invalidating all the pointers to it. Lovely! It does EXACTLY what it was supposed to help avoid 
 * (i.e. the invalidation of pointers. )
 *
 * Solution: Instead of having one 2D array, have an array of them. Each of the 2D arrays will have a known size. That way, 
 * if we have n 2D arrays each with m elements in them, we can store m*n objects. It isn't hard to malloc a new array, and 
 * all the old arrays stay in the same place when that happens. We can find which array an object is in and its index in that
 * array quite easily, too. 
 *
 * Note: The first row (index 0) is the type, and the second is the pointer to the data.
 * -------------------------------------------------------------------------------------------------------
 *
 * The memory manager itself has four external functions: InitMem(), the initilization function, which should be called as the
 * very FIRST thing in an application, VyMemCollect(), which forces a garbage collection cycle, and also VyMallocate(), which
 * allocates space on the heap for a certain number of bytes and returns a pointer to that space. The last function is FreeHeap(), which just
 * frees the memory on the heap, as well as the heap structure itself. This should be called at the end of the program to ensure that
 * all memory is released.
 *
 * If the heap that the memory is requested on is too small, then VyMallocate() automatically calls the garbage collector. The
 * garbage collector does a few things: it determines which objects are still reachable, then creates a new, larger heap, copies those objects
 * to the heap, and then free's the old heap memory. While it copies those objects to the new heap, it updates the pointers to them in
 * the heap structure so that the interpreter knows where to reach those objects. 
 */

struct VyMemHeap {
	/* Heap data */
	int heapSize;
	int usedSpace;

	/* An array of 2-D arrays. The 2-D arrays contain void*'s. */
	void**** idMapArray;
	int numIdMaps;
	int idMapSize;

	int objectsOnHeap;

	/* The pointers to the heap base and free memory */
	void* heapBase;
	void* freeMem;

};

/* Initialize the memory manager */
void InitMem();

/* Allocate a number of bytes on the heap and return a pointer to it */
void* VyMallocate(int, VyMemHeap*);

/* Force a garbage collection cycle to occur */
void VyMemCollect(VyMemHeap*);

/* Delete the heap */
void FreeHeap(VyMemHeap*);

#endif /* V_MEMORY_H */
