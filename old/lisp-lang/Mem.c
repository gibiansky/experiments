#include "Vyion.h"

/* How many bytes the GC should allocate at start time */
#define INIT_ALLOC 1024*100

/* How much the allocator should allocate every time more memory is needed */
#define ALLOC_STEP 1.75

/* A temporary holder for the base of a heap when the new heap is created */
void* tempBase = NULL;

/* Initialize the garbage collector and heap and allocate a starting amount of memory */
void InitMem(){
	/* Initialize the heap data structure */
	VyMemHeap* heap = malloc(sizeof(VyMemHeap));
	heap->objectsOnHeap = heap->usedSpace = 0;
	heap->idMapSize = 10000;

	/* Let CreateObj() do the initial allocation too */
	heap->numIdMaps = 0;
	heap->idMapArray = NULL;

	/* And allocate the heap memory itself */
	heap->heapBase = heap->freeMem = malloc(INIT_ALLOC);
	heap->heapSize = INIT_ALLOC;

	/* Set this heap as the current memory heap */
	SetMemoryHeap(heap);
}

/* Free the remaining memory */
void FreeHeap(VyMemHeap* heap){
	free(heap);	
}

/* Force a collection cycle to happen */
void VyMemCollect(VyMemHeap* heap){
	void* newHeap = calloc(1, heap->heapSize * ALLOC_STEP);
	if(newHeap == NULL){
		printf("Not enough space for large heap. Dead.");		
		fflush(stdout);
	}
	heap->heapSize *= ALLOC_STEP;
	void* freeMemStart = newHeap;

	int id;
	for(id = 0; id < heap->objectsOnHeap; id++){
		int objIndex = id % heap->idMapSize;
		int idMapNum = id/heap->idMapSize;

		int objSize = DataSize(ObjType(id)) + sizeof(int);
		void* toCopy = heap->idMapArray[idMapNum][1][objIndex] - sizeof(int); 

		heap->idMapArray[idMapNum][1][objIndex] = freeMemStart + sizeof(int);
		memcpy(freeMemStart, toCopy, objSize);
		freeMemStart += objSize;
	}
	free(heap->heapBase);
	heap->heapBase = newHeap;
	heap->freeMem = freeMemStart;
}

/* Provide a way for Vyion to allocate memory on the heap */
void* VyMallocate(int size, VyMemHeap* heap){

	/* Check whether the heap ran out of space, and if it has, it's time to for a garbage collection cycle */
	if(size + heap->usedSpace > heap->heapSize){
		printf("Heap: %p ", heap->freeMem);
		VyMemCollect(heap);
		printf("\nHeap: %p ", heap->freeMem);
		printf("? %d ?\n", heap->objectsOnHeap);
	}

	/* Store and then increment the free memory location */
	heap->usedSpace += size;
	heap->freeMem += size;
	return heap->freeMem - size;
}
