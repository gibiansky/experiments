#ifndef PARSE_TREE_H
#define PARSE_TREE_H

#include "Vyion.h"

/* Nodes of a parse tree */
struct VyParseTree;

typedef struct {
	struct VyParseTree** list;
	int length;
} list_node;

typedef struct {
	char* str;
} ident_node;

typedef struct {
	VyNumber** num;
} num_node;

typedef struct {
	struct VyParseTree* data;
} quote_node;

typedef struct {
	struct VyParseTree* data;
	int splice;
} subst_node;

typedef struct {
	struct VyParseTree* obj;
	struct VyParseTree* ref;
} ref_node;

typedef struct {
	char* str;
} string_node;

typedef struct {
	char* message;
} error_node;

/* The data of a parse tree node */
typedef union {
	list_node list;
	ident_node ident;
	num_node num;
	string_node str;
	quote_node quote;
	subst_node subst;
	ref_node ref;
	error_node error;
} tree_node_data;

/* A parse tree node */
struct VyParseTree {
	int type;
	Position* pos;
	tree_node_data* data;
};

/* Create empty parse trees of a certain type  */
VyParseTree* MakeListTree();
VyParseTree* MakeNum();
VyParseTree* MakeIdent();
VyParseTree* MakeString();

/* Quote an expression or get the expression in a quote */
VyParseTree* Quote(VyParseTree*);
int IsQuote(VyParseTree*);

/* Put something in/out of a substitution */
VyParseTree* Substitution(VyParseTree*, int);
int IsSubstitution(VyParseTree*);
int IsSplicingSubstitution(VyParseTree*);

/* Create an object reference */
VyParseTree* Reference(VyParseTree*, VyParseTree*);

/* Retrieve either the obj or ref part of the reference */
VyParseTree* GetObj(VyParseTree*);
VyParseTree* GetRef(VyParseTree*);

/* Make an error node */
VyParseTree* ParseError(char*);

/* List operations (adding, retrieving, and finding list size) */
int AddToList(VyParseTree*,VyParseTree*);
VyParseTree* GetListData(VyParseTree*,int);
inline int ListTreeSize(VyParseTree*);
VyParseTree* ListTreeHead(VyParseTree*);

/* Get and set the associated string data for this node */
int SetStrData(VyParseTree*, char*);
char* GetStrData(VyParseTree*);

/* Get/Set Number Data */
void SetNumberData(VyParseTree*, VyNumber**);
VyNumber** GetNumberData(VyParseTree*);

/* Set the position in the original text of this node */
void SetPosition(VyParseTree*, Position*);

/* Delete a parse tree and the used memory */
void DeleteParseTree(VyParseTree*);

#endif /* PARSE_TREE_H */
