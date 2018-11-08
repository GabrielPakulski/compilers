// João Vitor de Camargo
// Marcellus Farias
#include "iloc.h"

typedef struct list_label {
	int num_labels;
	char** list;
} lbl_list;

typedef struct node {
	struct 	Lexeme* token;
	
	char*	result_reg;
	iloc_op_list* code;
	
	int		conversion;
	int		type;
	char*	user_type;
	
	int		is_literal;
	int		point; // Used for pipes
	
	int 	children_num;
	struct 	node **children;

	//used for code
	lbl_list false_list;
	lbl_list true_list;
} Node;

Node* new_node(struct Lexeme* token);

void set_node_type(Node* token, int type);

void set_node_conversion(Node* token, int conversion);

void add_node(Node *root, Node *child);

void print_token(struct Lexeme* lex_val);

void add_list(Node* node, char* label, int bool);

/*
	The following functions may have
	automated use, so the portugues name
	will be preserved.
*/

void descompila(void *node);

void libera(void *node);