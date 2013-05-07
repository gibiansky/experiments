#ifndef FLOW_CONTROL_H
#define FLOW_CONTROL_H

#include "Vyion.h"

/* A flow control object is used for various flow control jumps. 
 * The different types of flow control are declared here as #define's,
 * and every flow control can have associated data stored in the void*.  
 */

/* Flow control types */
#define FLOWGO 0
#define FLOWRETURN 1

struct VyFlowControl {
	void* data;
	int type;
};

VyFlowControl** CreateFlowControl(int, void*);


#endif /* FLOW_CONTROL_H */
