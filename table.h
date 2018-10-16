// João Vitor de Camargo
// Marcellus Farias

#include "lexeme.h"
#include "nature.h"
#include "size.h"

#define NO_TABLES -1
#define NO_LINES -1

typedef struct function_arguments {
	int is_user_type;
	int is_const;

	int token_type;
	char * user_type;
	char * token_name;
	
} func_args;

// The user_type does not have arguments that are also user_types. We must define the access_modification arguments.

#define PRIVATE 0
#define PUBLIC 1
#define PROTECTED 2

typedef struct user_type_arguments {

	char * scope;
	int token_type;

	char * token_name;

} user_type_args;

typedef struct line {
	
	char * token_name; // KEY

	int declaration_line;	// Necessary information
	int nature;
	int token_type;
	int token_size;

	// When the program sees a funcion call/declaration OR an user type declaration, it must save the arguments in both cases
	// Thats the reason we create these flags (to make it more readable) and these structs (to save it in a more organizable way)

	int is_function;
	int is_user_type;
	int array_size; 	//actually also works as a flag (0 for false)

	func_args * function_args;
	user_type_args * user_type_args;

	int num_user_type_args;

	// The real value from the token
	Lexeme lexeme; //Really need this?

	//	Values if it is an array
	Lexeme * array_vals;

} table_line;

typedef struct table {
	int num_lines;
	table_line *lines;

} table;

table create_table();

/*
	TABLE STACK



*/

typedef struct table_stack {
	int num_tables;
	table* array;
} table_stack;

int is_empty(table_stack * table_stack);

void push(table_stack * table_stack, table item);

void pop(table_stack * table_stack);

// FUNCTIONS that manage the information of the tables.

int is_declared (table_stack * stack, char* token);
void add_user_type(table_stack * stack, Lexeme * token);
void add_user_type_properties(table_stack * stack, char * key, char * current_scope, Lexeme * token);
table_line inicialize_line(Lexeme * token_name);

void print_stack(table_stack * stack);
void print_cabecalho_table_part1();
void print_cabecalho_table_part2();

void initialize_stack();