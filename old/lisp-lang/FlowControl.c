#include "Vyion.h"

VyFlowControl** CreateFlowControl(int type, void* data){
	VyFlowControl** ctrl = CreateFlowControlObj();		
	ctrl[0]->type = type;
	ctrl[0]->data = data;

	return ctrl;
}
