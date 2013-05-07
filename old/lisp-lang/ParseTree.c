#include "Vyion.h"

/* Create a general empty parse tree of a certain type */
VyParseTree* MakeParseTree(int type){
	VyParseTree* tree = malloc(sizeof(VyParseTree));
	tree->type = type;
	tree->data = malloc(sizeof(tree_node_data));
	tree->pos = NULL;
	return tree;
}

/* Create a list */
VyParseTree* MakeListTree(){
	VyParseTree* list = MakeParseTree(TREE_LIST);
	list->data->list.length = 0;
	list->data->list.list = NULL;
	return list;
}

/* Create a number */
VyParseTree* MakeNum(){
	VyParseTree* num = MakeParseTree(TREE_NUM);
	return num;
}

/* Create a string */
VyParseTree* MakeString(){
	VyParseTree* str = MakeParseTree(TREE_STR);
	return str;
}

/* Create an ident */
VyParseTree* MakeIdent(){
	VyParseTree* ident = MakeParseTree(TREE_IDENT);
	return ident;
}

/* Put something in a quote */
VyParseTree* Quote(VyParseTree* elem){
	/* The resulting list, (quote ...) */
	VyParseTree* qList = MakeListTree();

	/* The quote ident */
	VyParseTree* qIdent = MakeIdent();
	SetStrData(qIdent, "quote");

	/* Add to the list */
	AddToList(qList, qIdent);
	AddToList(qList, elem);
	
	return qList;
}

/* Find out if a list is a quote list */
int IsQuote(VyParseTree* qt){
	/* It must be a list with two elements to be a quote */
	if(qt->type == TREE_LIST){
		if(ListTreeSize(qt) == 2){
			/* And the first element must be the quote ident */
			if(GetListData(qt,0)->type == TREE_IDENT && strcmp(GetStrData(GetListData(qt, 0)), "quote") == 0){
				return 1;	
			}
		}
	}

	/* Assume false otherwise */
	return 0;
}

/* Put something in a substitution */
VyParseTree* Substitution(VyParseTree* elem, int splice){
	/* The resulting list, (quote ...) */
	VyParseTree* sList = MakeListTree();

	/* The quote ident */
	VyParseTree* sIdent = MakeIdent();
	if(splice){
		SetStrData(sIdent, "splicing-substitution");
	}else{
		SetStrData(sIdent, "substitution");
	}

	/* Add to the list */
	AddToList(sList, sIdent);
	AddToList(sList, elem);
	
	return sList;
}

/* Find out if a list is a substitution list */
int IsSubstitution(VyParseTree* qt){
	/* Same rules apply as for IsQuote, except the ident is different */
	if(qt->type == TREE_LIST){
		if(ListTreeSize(qt) == 2){
			if(GetListData(qt,0)->type == TREE_IDENT){
				char* str = GetStrData(GetListData(qt, 0));
				if(strcmp(str, "substitution") == 0 || strcmp(str, "splicing-substitution") == 0){
					return 1;		
				}
				
			}
		}
	}

	/* Assume false otherwise */
	return 0;
}

/* Find whether it is a splicing substitution */
int IsSplicingSubstitution(VyParseTree* subst){
	if(IsSubstitution(subst) 
			&& strcmp(GetStrData(GetListData(subst, 0)), "splicing-substitution") == 0){
		return 1;	
	}
	return 0;
}

/* Create a reference */
VyParseTree* Reference(VyParseTree* obj, VyParseTree* ref){
	VyParseTree* tree = MakeParseTree(TREE_REF);
	tree->type = TREE_REF;
	tree->data->ref.obj = obj;
	tree->data->ref.ref= ref;
	return tree;
}

/* Make an error node */
VyParseTree* ParseError(char* message){
	VyParseTree* error = MakeParseTree(TREE_ERROR);
	error->data->error.message = message;
	return error;
}

/* Find the obj or ref parts of the reference */
inline VyParseTree* GetObj(VyParseTree* ref){
	return ref->data->ref.obj;
}
inline VyParseTree* GetRef(VyParseTree* ref){
	return ref->data->ref.ref;
}

/* Find the size of a list tree */
inline int ListTreeSize(VyParseTree* tree){
	return tree->data->list.length;
}

/* Add to a list and return it's size */
int AddToList(VyParseTree* tree, VyParseTree* item){
	/* If it isn't a list, return 0 */
	if(tree->type != TREE_LIST){
		return 0;
	}

	/* Allocate more memory and add the item */
	tree->data->list.list = realloc(tree->data->list.list, sizeof(VyParseTree*)*(ListTreeSize(tree)+ 1));
	tree->data->list.list[ListTreeSize(tree)] = item;

	/* Increment the list's size */
	tree->data->list.length++;

	return 1;
}


/* Get data from a list */
VyParseTree* GetListData(VyParseTree* tree, int index){
	return tree->data->list.list[index];
}

/* Get the first element of a list */
VyParseTree* ListTreeHead(VyParseTree* list){
	/* Validate that it is a list and has at least one element */
	if(list->type != TREE_LIST && ListTreeSize(list) > 0){
		return NULL;	
	}
	else{
		return GetListData(list, 0);
	}
}


/* Set or fetch string data for ident nodes  */
int SetStrData(VyParseTree* tree, char* str){
	/* Make sure it has an appropriate type */
	switch(tree->type){
		case TREE_IDENT:
			tree->data->ident.str = strdup(str);
			return 1;
		case TREE_STR:
			tree->data->str.str = strdup(str);
			return 1;
		default:
			return 0;
	}


}
char* GetStrData(VyParseTree* tree){
	/* Make sure it has an appropriate type */
	switch(tree->type){
		case TREE_IDENT:
			return tree->data->ident.str;
		case TREE_STR:
			return tree->data->str.str;
		default:
			return NULL;
	}


}

/* Get and set number data */
void SetNumberData(VyParseTree* tree, VyNumber** num){
	if(tree->type == TREE_NUM){
		tree->data->num.num = num;
	}
}
VyNumber** GetNumberData(VyParseTree* tree){
	if(tree->type == TREE_NUM){
		return tree->data->num.num; 
	}else{
		return NULL;	
	}
}

/* Set the position */
void SetPosition(VyParseTree* tree, Position* pos){
	/* Copy all the position data */
	if(tree->pos == NULL) {
		tree->pos = malloc(sizeof(Position));
		tree->pos->line = pos->line;
		tree->pos->indent = pos->indent;
		tree->pos->character = pos->character;
	}
}

/* Delete a parse tree */
void DeleteParseTree(VyParseTree* tree){
	/* Make sure you aren't freeing null pointers */
	if(tree != NULL){
		if(tree->data != NULL){
			/* Free all the sub-trees depending on the type */
			int treeType = tree->type;

			/* For identifiers the only associated data to free is the string data */
			if(treeType == TREE_IDENT){
				free(tree->data->ident.str);
			}

			/* For lists, free all the members of the list */
			else if(treeType == TREE_LIST){
				/* Iterate through and free all the elements */
				int i;
				for(i = 0; i < ListTreeSize(tree); i++){	
					VyParseTree* next = GetListData(tree,i);
					DeleteParseTree(next);
				}

				/* Free the used array */
				free(tree->data->list.list);
			}

			/* For references, free both parts of the reference */
			else if(treeType == TREE_REF){
				DeleteParseTree(GetObj(tree));
				DeleteParseTree(GetRef(tree));
			}



			/* Finally, free the rest of the tree and the data*/
			free(tree->data);
		}
		/* Free the position data */
		if(tree->pos != NULL){
			free(tree->pos);
		}
		free(tree);
	}
}


