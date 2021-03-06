%{
	// João Vitor de Camargo (274722) e Marcellus Farias (281984)
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include "include/tree.h"
	#include "include/lexeme.h"
	#include "include/table.h"
	#include "include/error.h"
	#include "include/conversions.h"
	#include "include/category.h"
	#include "include/debug_print.h"
	#include "include/iloc.h"
	
	extern int yylineno;
	extern void* arvore;
	extern int yylex_destroy(void);

	int type_args_counter = 0;
	user_type_args *type_arguments;
	char* scope = "public";

	int func_call_param_counter = 0;
	func_call_arg* function_arguments;

	global_var_args global_var;

	function_data function;

	int id_category = VARIABLE;

	int first_call_num_params = 0;
	int checked_first_call = FALSE;
	int last_piped_function_type = NOT_DECLARED;
	char* last_piped_function_type_name = NULL;

	int yylex(void);
	void yyerror(char const *s);
%}

%verbose
%define parse.error verbose

%union {
	struct Lexeme* valor_lexico;
	struct node* node;
}

%token <valor_lexico> TK_PR_INT
%token <valor_lexico> TK_PR_FLOAT
%token <valor_lexico> TK_PR_BOOL
%token <valor_lexico> TK_PR_CHAR
%token <valor_lexico> TK_PR_STRING
%token <valor_lexico> TK_PR_IF
%token <valor_lexico> TK_PR_THEN
%token <valor_lexico> TK_PR_ELSE
%token <valor_lexico> TK_PR_WHILE
%token <valor_lexico> TK_PR_DO
%token <valor_lexico> TK_PR_INPUT
%token <valor_lexico> TK_PR_OUTPUT
%token <valor_lexico> TK_PR_RETURN
%token <valor_lexico> TK_PR_CONST
%token <valor_lexico> TK_PR_STATIC
%token <valor_lexico> TK_PR_FOREACH
%token <valor_lexico> TK_PR_FOR
%token <valor_lexico> TK_PR_SWITCH
%token <valor_lexico> TK_PR_CASE
%token <valor_lexico> TK_PR_BREAK
%token <valor_lexico> TK_PR_CONTINUE
%token <valor_lexico> TK_PR_CLASS
%token <valor_lexico> TK_PR_PRIVATE
%token <valor_lexico> TK_PR_PUBLIC
%token <valor_lexico> TK_PR_PROTECTED
%token <valor_lexico> TK_OC_LE
%token <valor_lexico> TK_OC_GE
%token <valor_lexico> TK_OC_EQ
%token <valor_lexico> TK_OC_NE
%token <valor_lexico> TK_OC_AND
%token <valor_lexico> TK_OC_OR
%token <valor_lexico> TK_OC_SL
%token <valor_lexico> TK_OC_SR
%token <valor_lexico> TK_OC_FORWARD_PIPE
%token <valor_lexico> TK_OC_BASH_PIPE
%token <valor_lexico> TK_LIT_INT
%token <valor_lexico> TK_LIT_FLOAT
%token <valor_lexico> TK_LIT_FALSE
%token <valor_lexico> TK_LIT_TRUE
%token <valor_lexico> TK_LIT_CHAR
%token <valor_lexico> TK_LIT_STRING
%token <valor_lexico> TK_IDENTIFICADOR
%token <valor_lexico> TOKEN_ERRO
%token <valor_lexico> ',' ';' ':' '(' ')' '{' '}' '[' ']' '+' '-' '|' '?' '*' '/' '<' '>' '=' '!' '&' '%' '#' '^' '.' '$'

%type <node> programa 

%type <node> set_tree
%type <node> start
%type <node> scope
%type <node> var 
%type <node> func_type
%type <node> func_arg_types
%type <node> type
%type <node> bool
%type <node> pipe
%type <node> new_type 
%type <node> param_begin
%type <node> param_body
%type <node> param_end
%type <node> global_var
%type <node> global_var_vec
%type <node> global_var_begin
%type <node> global_var_type
%type <node> index
%type <node> func
%type <node> func_begin
%type <node> func_name_user_type
%type <node> func_name
%type <node> func_params
%type <node> func_params_end
%type <node> func_body
%type <node> cmd_block
%type <node> cmd_ident
%type <node> cmd
%type <node> input
%type <node> output
%type <node> output_vals
%type <node> if_then 
%type <node> bool_expr
%type <node> else
%type <node> while
%type <node> do_while
%type <node> continue
%type <node> break
%type <node> return
%type <node> for
%type <node> cmd_for
%type <node> for_fst_list
%type <node> for_scd_list
%type <node> foreach
%type <node> foreach_list
%type <node> foreach_count
%type <node> switch
%type <node> case
%type <node> cmd_fix_local_var
%type <node> cmd_fix_attr
%type <node> cmd_fix_call
%type <node> static_var		
%type <node> const_var
%type <node> var_end
%type <node> var_lit
%type <node> attr
%type <node> piped_expr
%type <node> un_op
%type <node> not_null_un_op
%type <node> expr
%type <node> expr_vals
%type <node> id_for_expr
%type <node> id_seq
%type <node> id_seq_field
%type <node> id_seq_simple
%type <node> func_call_params
%type <node> func_call_params_body
%type <node> func_call_params_end
%type <node> opt_prefixes

%left TK_OC_OR
%left TK_OC_AND
%left '|'
%left '^'
%left '&'
%left TK_OC_NE TK_OC_EQ
%left '<' '>' TK_OC_LE TK_OC_GE
%left '+' '-'
%left '*' '/' '%'


%start programa

%%

/*
	The rules are basically always the same.
	First token = new_node($$);
	Other tokens = children of the first token;
	For the children:
	when is a really a token = add_node($$, new node($x))
	when is another rule = add_node($$, $x),
		because the new_node will be created on the
		rule itself. Follow the pattern.
*/

programa :  initializer set_tree destroyer {}

set_tree	: start 
			{
				$$ = $1;
				if ($$->code == NULL) {
					$$->code = new_op_list();
				} else {
					iloc_op_list* jump_to_main = new_op_list();
					char* main_label = get_function_label("main");
					add_op(jump_to_main, loadi(512, "rfp"));
					add_op(jump_to_main, loadi(1024, "rsp"));
					add_op(jump_to_main, loadi(23, "rbss"));
					add_op(jump_to_main, jumpi(main_label));
					$$->code = concat_code(jump_to_main, $$->code);
				}
				add_op($$->code, halt());
				arvore = $1;
			}

initializer : %empty
			{
				init_table_stack();
			}

destroyer : %empty
			{
				free_table_stack();
			}

start : new_type start
			{ 
				$$ = $1; 
				add_node($$, $2); 
				$$->code = $2->code;
			}
		| global_var start 
			{ 
				$$ = $1; 
				add_node($$, $2); 
				$$->code = $2->code; 
			}
		| func start 
			{	$$ = $1; 
				add_node($$, $2);
				char* curr_func = $$->children[0]->token->value.v_string;
				char* curr_label = get_function_label(curr_func);
				if ($$->code == NULL) {
					$$->code = new_op_list();
				}
				int curr_var_space = get_current_var_space(curr_func);
				iloc_op_list* rsp_update = new_op_list();
				char* return_reg = new_reg();
				char* old_rsp_reg = new_reg();
				char* old_rfp_reg = new_reg();
				if (strcmp(curr_func, "main") != 0) {
					int num_params = get_func_num_params(curr_func);
					add_op(rsp_update, i2i("rsp", "rfp"));
					add_op(rsp_update, addi("rsp", curr_var_space + 4*(FIELDS_ON_RA+num_params), "rsp"));
				} else {
					add_op(rsp_update, addi("rsp", curr_var_space, "rsp"));
				}
				$$->code = concat_code(rsp_update, $$->code);
				$$->code = put_label_before_code($$->code, curr_label);
				if (strcmp(curr_func, "main") != 0) {
					add_op($$->code, loadai("rfp", RETURN_ADDRESS, return_reg));
					add_op($$->code, loadai("rfp", OLD_RSP, old_rsp_reg));
					add_op($$->code, loadai("rfp", OLD_RFP, old_rfp_reg));
					add_op($$->code, addi(old_rsp_reg, 0, "rsp"));
					add_op($$->code, addi(old_rfp_reg, 0, "rfp"));
					add_op($$->code, jump(return_reg));
				}
				if ($2->code != NULL) {
					$$->code = concat_code($1->code, $2->code);
				}
			}
		| %empty 
			{ 
				$$ = new_node(NULL); 
				$$->code = NULL; 
			}

type : TK_PR_INT
			{ 	
				$$ = new_node($1); 
				set_node_type($$, INT);
			}
		| TK_PR_FLOAT
			{ 
				$$ = new_node($1); 
				set_node_type($$, FLOAT);
			}
		| TK_PR_BOOL
			{ 
				$$ = new_node($1);   
				set_node_type($$, BOOL);
			}
		| TK_PR_CHAR
			{ 
				$$ = new_node($1);  
				set_node_type($$, CHAR);
			}
		| TK_PR_STRING
			{ 
				$$ = new_node($1); 
				set_node_type($$, STRING);
			}

func_type  :  TK_PR_INT
			{ 	
				$$ = new_node($1); 
				set_node_type($$, INT);
				function.type = INT;
			}
		| TK_PR_FLOAT
			{ 
				$$ = new_node($1); 
				set_node_type($$, FLOAT);
				function.type = FLOAT;
			}
		| TK_PR_BOOL
			{ 
				$$ = new_node($1);   
				set_node_type($$, BOOL);
				function.type = BOOL;
			}
		| TK_PR_CHAR
			{ 
				$$ = new_node($1);  
				set_node_type($$, CHAR);
				function.type = CHAR;
			}
		| TK_PR_STRING
			{ 
				$$ = new_node($1); 
				set_node_type($$, STRING);
				function.type = STRING;
			}

scope   : TK_PR_PRIVATE
			{ 				
				$$ = new_node($1);
				scope = $1->value.v_string;
			}
		| TK_PR_PUBLIC
			{ 				
				$$ = new_node($1); 
				scope = $1->value.v_string;
			}
		| TK_PR_PROTECTED
			{ 				
				$$ = new_node($1); 
				scope = $1->value.v_string;
			}

var     : TK_PR_CONST type TK_IDENTIFICADOR
			{ 	
				$$ = new_node($1); 
				add_node($$, $2);
				add_node($$, new_node($3));

				if (function.args_counter == 0)
					function.function_args = malloc(sizeof(func_args));
				else 
					function.function_args = realloc(function.function_args, (function.args_counter+1)*sizeof(func_args));

				function.function_args[function.args_counter].name = $3->value.v_string;
				function.function_args[function.args_counter].is_const = TRUE;
				function.function_args[function.args_counter].type = $2->type;
				function.function_args[function.args_counter].user_type = $2->user_type;

				function.args_counter++;

				int index;
				for (index = 0; index < function.args_counter-1; index++)
					if (strcmp(function.function_args[index].name, $3->value.v_string) == 0)
						set_error(ERR_DECLARED);

			}
		| func_arg_types TK_IDENTIFICADOR
			{ 	
				$$ = $1; 
				add_node($$, new_node($2));

				if (function.args_counter == 0)
					function.function_args = malloc(sizeof(func_args));
				else 
					function.function_args = realloc(function.function_args, (function.args_counter+1)*sizeof(func_args));

				function.function_args[function.args_counter].name = $2->value.v_string;
				function.function_args[function.args_counter].is_const = FALSE;
				function.function_args[function.args_counter].type = $1->type;
				function.function_args[function.args_counter].user_type = $1->user_type;

				function.args_counter++;

				int index;
				for (index = 0; index < function.args_counter-1; index++)
					if (strcmp(function.function_args[index].name, $2->value.v_string) == 0)
						set_error(ERR_DECLARED);
			}

func_arg_types: type
			{ 
				$$ = $1; 

				$$->user_type = NULL;
			}
		| TK_IDENTIFICADOR
			{ 
				$$ = new_node($1); 

				if(is_declared($1->value.v_string) == NOT_DECLARED)
					set_error(ERR_UNDECLARED);

				$$->type = USER_TYPE;
				$$->user_type = $1->value.v_string;
			}

bool    : TK_LIT_TRUE
			{ 
				$$ = new_node($1); 
			}
		| TK_LIT_FALSE
			{ 
				$$ = new_node($1); 
			}

pipe 	: TK_OC_FORWARD_PIPE
			{ 
				$$ = new_node($1); 
				if (checked_first_call == FALSE) {
					first_call_num_params = func_call_param_counter;
					checked_first_call = TRUE;
				}
			}
		| TK_OC_BASH_PIPE
			{ 
				$$ = new_node($1); 
				if (checked_first_call == FALSE) {
					first_call_num_params = func_call_param_counter;
					checked_first_call = TRUE;
				}
			}

new_type    : TK_PR_CLASS TK_IDENTIFICADOR '[' param_begin ';'
				{	
					$$ = new_node($1);
					add_node($$, new_node($2));
					add_node($$, new_node($3));
					add_node($$, $4);
					add_node($$, new_node($5));	

					int declaration_line = is_declared($2->value.v_string);
					if(declaration_line != NOT_DECLARED) {				
						set_error(ERR_DECLARED);
					} else {
						add_user_type($2);
					}

					int index;
					for (index = 0; index < type_args_counter; index++)
						add_user_type_properties($2->value.v_string, type_arguments[index]);

					free(type_arguments);
					type_args_counter = 0;
				}

param_begin : scope param_body
				{ 	
					$$ = $1;
					add_node($$, $2);
				}
			| param_body
				{	
					$$ = $1; 					
				}

param_body  : type TK_IDENTIFICADOR param_end
				{	
					$$ = $1;
					add_node($$, new_node($2));
					add_node($$, $3);

					if (type_args_counter == 0) 
						type_arguments = malloc(sizeof(user_type_args));
					else
						type_arguments = realloc(type_arguments, (type_args_counter+1)*sizeof(user_type_args));
				
					type_arguments[type_args_counter].token_type = $1->type;
					type_arguments[type_args_counter].scope = scope;
					type_arguments[type_args_counter].token_name = $2->value.v_string;

					type_args_counter++;

					int index;
					for (index = 0; index < type_args_counter-1; index++)
						if (strcmp(type_arguments[index].token_name, $2->value.v_string) == 0)
							set_error(ERR_DECLARED);
					
					scope = "public";
				}

param_end   : ':' param_begin
				{	
					$$ = new_node($1);
					add_node($$, $2);
				}
			| ']'
				{	
					$$ = new_node($1);
				} 

global_var       : TK_IDENTIFICADOR global_var_vec 
					{	
						$$ = new_node($1);
						add_node($$, $2);

						int declaration_line = is_declared($1->value.v_string);
						if (declaration_line != NOT_DECLARED) {
							set_error(ERR_DECLARED);
						} 
						
						global_var.name = $1->value.v_string;
						add_global_var(global_var, $1);

						global_var = initialize_global_var_args();
						
					}

global_var_vec  : '[' index ']' global_var_begin
					{	
						$$ = new_node($1);
						add_node($$, $2);
						add_node($$, new_node($3));
						add_node($$, $4);

						global_var.is_array = TRUE;
					}
				| global_var_begin
					{
						$$ = $1;

						global_var.is_array = FALSE;
					}

global_var_begin	: TK_PR_STATIC global_var_type
						{
							$$ = new_node($1);
							add_node($$, $2);

							global_var.is_static = TRUE;
						}
					| global_var_type
						{
							$$ = $1;

							global_var.is_static = FALSE;
						}

global_var_type	: type ';'
					{
						$$ = $1;
						add_node($$, new_node($2));

						global_var.type = $1->type;
					}
				| TK_IDENTIFICADOR ';'
					{
						$$ = new_node($1);
						add_node($$, new_node($2));

						if(is_declared($1->value.v_string) == NOT_DECLARED)						
							set_error(ERR_UNDECLARED);

						global_var.type = USER_TYPE;
						global_var.user_type = $1->value.v_string;
						global_var.user_type_size = get_user_type_size($1->value.v_string);
					}

index	: TK_LIT_INT 
			{
				$$ = new_node($1);

				global_var.array_size = $1->value.v_int;
			}
		| '+' TK_LIT_INT
			{
				$$ = new_node($1);
				add_node($$, new_node($2));

				global_var.array_size = $2->value.v_int;
			}

func 	: TK_PR_STATIC func_begin
			{
				$$ = new_node($1);
				add_node($$, $2);
			}
		| func_begin
			{ 				
				$$ = $1;
			}

func_begin      : func_type func_name '(' func_params
					{
						$$ = $1;
						add_node($$, $2);
						add_node($$, new_node($3));
						add_node($$, $4);					
						
						$$->code = $4->code;
					}

				| func_name_user_type '(' func_params
					{

						$$ = $1;
						add_node($$, new_node($2));
						add_node($$, $3);
						
					}

func_name_user_type	: TK_IDENTIFICADOR TK_IDENTIFICADOR
				{
					$$ = new_node(NULL);
					add_node($$, new_node($1));
					add_node($$, new_node($2));

					int declaration_line = is_declared($2->value.v_string);
					if (declaration_line != NOT_DECLARED)
						set_error(ERR_DECLARED);

					if(is_declared($1->value.v_string) == NOT_DECLARED)
						set_error(ERR_UNDECLARED);

					$$->type = USER_TYPE;
					$$->user_type = $1->value.v_string;

					function.lexeme = $2;

					function.type = USER_TYPE;
					function.type_name = $1->value.v_string;

				}


func_name 	: TK_IDENTIFICADOR
				{
					$$ = new_node($1);

					int declaration_line = is_function_declared($1->value.v_string);
					if (declaration_line != NOT_DECLARED)
						set_error(ERR_DECLARED);

					function.lexeme = $1;
				}

func_params     : ')' add_func func_body
					{
						$$ = new_node($1);
						add_node($$, $3);

						$$->code = $3->code;
					}
				| var func_params_end
					{
						$$ = $1;
						add_node($$, $2);

						$$->code = $2->code;
					}

func_params_end : ')' add_func func_body
					{
						$$ = new_node($1);
						add_node($$, $3);

						$$->code = $3->code;
					}
				| ',' var func_params_end
					{
						$$ = new_node($1);
						add_node($$, $2);
						add_node($$, $3);

						$$->code = $3->code;
					}

add_func 		: %empty
					{
						add_function(function.type, function.type_name, function.args_counter, function.function_args, function.lexeme);	
					}

func_body       : '{' push_table cmd_block 
					{
						$$ = new_node($1);
						add_node($$, $3);

						$$->code = $3->code;
					}

push_table		: %empty
					{
						push(create_table());
					}

pop_table		: %empty
					{	
						//print_stack(stack);					
						pop();
						function.function_args = NULL;
						function.type = 0;
						function.args_counter = 0;
						function.type_name = NULL;
					}

cmd_block	: '}' pop_table
				{
					$$ = new_node($1);
					$$->code = NULL;
				}
			| cmd cmd_block
				{
					$$ = $1;
					add_node($$, $2);	
					if ($2->code != NULL) {
						$$->code = concat_code($1->code, $2->code);
					}				
				} 

cmd_ident	: TK_IDENTIFICADOR
				{
					$$ = new_node($1);
					$$->type = USER_TYPE;
					$$->user_type = $1->value.v_string;

					int declaration_line = is_declared($1->value.v_string);
					if(declaration_line == NOT_DECLARED) 
						set_error(ERR_UNDECLARED);

				}

cmd 		: cmd_ident cmd_fix_local_var ';'
					{
						$$ = $1;
						add_node($$, $2);
						add_node($$, new_node($3));
	
						int declaration_line = is_declared_on_current_table($2->token->value.v_string);
						int param_type = get_param_type($2->token->value.v_string, function.args_counter, function.function_args);
						if(declaration_line != NOT_DECLARED || param_type != NOT_DECLARED) 
							set_error(ERR_DECLARED);
						else 
							add_local_var($1->type, $1->user_type, FALSE, FALSE, $2->token);
					}
				| cmd_ident cmd_fix_attr ';'
					{
						$$ = $1;
						add_node($$, $2);
						add_node($$, new_node($3));

						char* type_name;
						int type = get_id_type($1->token->value.v_string, &type_name);

						if ($2->user_type != NULL)
							type = get_id_field_type(type_name, $2->user_type);

						if (type != $2->type) {
							if (can_convert(type, $2->type) == FALSE) {
								set_error(ERR_WRONG_TYPE);
							} else {
								$2->conversion = get_conversion(type, $2->type);
							}
						} else if (type == USER_TYPE) {
							if (strcmp(type_name, $1->user_type) != 0) {
								set_error(ERR_WRONG_TYPE);
							}
						}

						int category = get_category($1->token->value.v_string);
						if (category != id_category) {
							if ($1->type != USER_TYPE || id_category != USER_TYPE)
								switch (category) {
									case FUNCTION:
										set_error(ERR_FUNCTION); break;
									case USER_TYPE:
										set_error(ERR_USER); break;
									case ARRAY:
										set_error(ERR_VECTOR); break;
									default:
										set_error(ERR_VARIABLE); break;
								}
						}
						
						if($1->type == USER_TYPE && $2->type == STRING) {
							update_string_size($1->token, $2->token);							
						}

						if ($2->code != NULL){
							$$->code = $2->code;
						
							char* displacement_reg = get_base_reg($1->token->value.v_string);
							int value = get_mem_address($1->token);
							//add_op($$->code, loadai(displacement_reg, get_mem_address($1->token), reg_temp));
							add_op($$->code, storeai($2->result_reg, value, displacement_reg));	
						}																				
					}
				| cmd_ident cmd_fix_call ';'
					{
						$$ = $1;
						add_node($$, $2);
						add_node($$, new_node($3));

						int num_args = get_func_num_params($1->token->value.v_string);
						int category = get_category($1->token->value.v_string);
						int* expected_types = get_func_params_types($1->token->value.v_string);

						if (category == FUNCTION) {
							if (num_args == func_call_param_counter) {
								int index;
								for (index = 0; index < num_args; index++) {
									if (expected_types[index] != function_arguments[index].type) {
										if (can_convert(expected_types[index], function_arguments[index].type) == FALSE) {
											set_error(ERR_WRONG_TYPE_ARGS);	
										} 
									}
								}
							} else if (num_args > func_call_param_counter) {
								set_error(ERR_MISSING_ARGS);
							} else {
								set_error(ERR_EXCESS_ARGS);
							}
						} else if (category == USER_TYPE) {
							set_error(ERR_USER);
						} else if (category == ARRAY) {
							set_error(ERR_VECTOR);
						} else {
							set_error(ERR_VARIABLE);
						}


						if ($2->type != NOT_DECLARED) {
							char* dummy;
							int func_type = get_id_type($1->token->value.v_string, &dummy);
							if (func_type != $2->type) {
								if (can_convert(func_type, $2->type) == FALSE) {
									set_error(ERR_WRONG_TYPE);
								}
							}
						}

						free(expected_types);
						free(function_arguments);
						function_arguments = NULL;
						func_call_param_counter = 0;

					}
				| opt_prefixes type TK_IDENTIFICADOR var_end ';'
					{	

						$$ = $1;
						add_node($$, $2);
						add_node($$, new_node($3));
						add_node($$, $4);
						add_node($$, new_node($5));

						int declaration_line = is_declared_on_current_table($3->value.v_string);
						int param_type = get_param_type($3->value.v_string, function.args_counter, function.function_args);
						
						if(declaration_line != NOT_DECLARED || param_type != NOT_DECLARED){
							set_error(ERR_DECLARED);
						}
						else {
							add_local_var($2->type, NULL, FALSE, FALSE, $3);
						}

						if ($4->type != NOT_DECLARED) 
							if ($2->type == $4->type) {
								if ($2->type == USER_TYPE)
									if (strcmp($2->user_type, $4->user_type) != 0){
										set_error(ERR_WRONG_TYPE);		
									}
							} else 
								if (can_convert($2->type, $4->type) == FALSE) {
									set_error(ERR_WRONG_TYPE);
								} else {
									$4->conversion = get_conversion($2->type, $4->type);
								}
						if($4->token != NULL && $2->type == STRING && $4->type == STRING) {
							update_string_size($3, $4->token);
						}	

						if($4->code != NULL) {
							$$->code = $4->code;
						
							char* displacement_reg = get_base_reg($3->value.v_string);					

							int value = get_mem_address($3);
							add_op($$->code, storeai($4->result_reg, value, displacement_reg));								
						}											
					}
				| if_then ';'
					{
						$$ = $1;
						add_node($$, new_node($2));

						$$->code = $1->code;
//						$$->result_reg = new_reg();
						
					}
				| while ';'
					{
						$$ = $1;
						add_node($$, new_node($2));

						$$->code = $1->code;
						//$$->result_reg = new_reg();

						//print_code($$->code);
					}
				| do_while ';'
					{
						$$ = $1;
						add_node($$, new_node($2));

						$$->code = $1->code;
						//$$->result_reg = new_reg();
					}
				| continue ';'
					{
						$$ = $1;
						add_node($$, new_node($2));
					}
				| break ';'
					{
						$$ = $1;
						add_node($$, new_node($2));
					}
				| return ';'
					{
						$$ = $1;
						add_node($$, new_node($2));
					}
				| for ';'
					{
						$$ = $1;
						add_node($$, new_node($2));
					}
				| foreach ';'
					{
						$$ = $1;
						add_node($$, new_node($2));
					}
				| switch ';'
					{
						$$ = $1;
						add_node($$, new_node($2));
					}
				| input ';'
					{
						$$ = $1;
						add_node($$, new_node($2));
					}
				| '{' push_table cmd_block ';'
					{
						$$ = new_node($1);
						add_node($$, $3);
						add_node($$, new_node($4));
					}
				| output 
					{
						$$ = $1;
					}
				| case
					{
						$$ = $1;
					}

opt_prefixes: TK_PR_STATIC {
				$$ = new_node($1);
				}
			| TK_PR_CONST {
				$$ = new_node($1);
				}
			| TK_PR_STATIC TK_PR_CONST {
				$$ = new_node($1);
				add_node($$, new_node($2));
				}
			| %empty {
				$$ = new_node(NULL);
			}
						
input 		: TK_PR_INPUT expr
				{
					$$ = new_node($1);
					add_node($$, $2);

					if ($2->is_literal == TRUE) {
						set_error(ERR_WRONG_PAR_INPUT);
					}

					simple_free_code($2->code);
				}

output 		: TK_PR_OUTPUT expr output_vals
				{
					$$ = new_node($1);
					add_node($$, $2);
					add_node($$, $3);

					if ($2->type != BOOL && $2->type != INT && $2->type != FLOAT) { 
						if ($2->type != STRING) {
							set_error(ERR_WRONG_PAR_OUTPUT);
						} else {
							if ($2->is_literal == FALSE) {
								set_error(ERR_WRONG_PAR_OUTPUT);
							}
						}
					}

					simple_free_code($2->code);
					
				}

output_vals : ';'
				{
					$$ = new_node($1);
				}
			| ',' expr output_vals
				{
					$$ = new_node($1);
					add_node($$, $2);
					add_node($$, $3);

					if ($2->type != BOOL && $2->type != INT && $2->type != FLOAT) { 
						if ($2->type != STRING) {
							set_error(ERR_WRONG_PAR_OUTPUT);
						} else {
							if ($2->is_literal == FALSE) {
								set_error(ERR_WRONG_PAR_OUTPUT);
							}
						}
					}

					simple_free_code($2->code);
				}

if_then 	: TK_PR_IF '(' bool_expr ')'
				TK_PR_THEN '{' push_table cmd_block else
				{
					$$ = new_node($1);
					add_node($$, new_node($2));
					add_node($$, $3);
					add_node($$, new_node($4));
					add_node($$, new_node($5));
					add_node($$, new_node($6));
					add_node($$, $8);
					add_node($$, $9);

					// $3->code = bool expression
					// Here we patch with new generated labels
					if ($3->code != NULL) {

						$$->code = $3->code;

						char* lbl_true = new_lbl();
						char* lbl_next = new_lbl();
						char* lbl_false = new_lbl();

						patch_list($3->code, $3->true_list, lbl_true);
						patch_list($3->code, $3->false_list, lbl_false);
						
						// We concat the created true-label, the code inside if block
						// 	and a jump to ignore else block 
						add_op($$->code, label(lbl_true));
						$$->code = concat_code($$->code, $8->code);
						add_op($$->code, jumpi(lbl_next));

						// We concat the created false-label and the code inside else block
						add_op($$->code, label(lbl_false));
						$$->code = concat_code($$->code, $9->code);
						
						// Add a label that represents the next op
						add_op($$->code, label(lbl_next));
						add_op($$->code, new_nop());
					}
				}

bool_expr : expr 
			{
				$$ = $1;

				if ($$->type != BOOL) {
					if (can_convert(BOOL, $$->type) == FALSE) {
						set_error(ERR_WRONG_TYPE);
					} else {
						$$->conversion = get_conversion(BOOL, $$->type);
					}					
				}
			}

else 		: TK_PR_ELSE '{' push_table cmd_block
				{
					$$ = new_node($1);
					add_node($$, new_node($2));
					add_node($$, $4);

					$$->code = $4->code;
				}
			|  %empty
				{
					$$ = new_node(NULL);
				}

while 		: TK_PR_WHILE '(' bool_expr ')'
				TK_PR_DO '{' push_table cmd_block
				{
					$$ = new_node($1);
					add_node($$, new_node($2));
					add_node($$, $3);
					add_node($$, new_node($4));
					add_node($$, new_node($5));
					add_node($$, new_node($6));
					add_node($$, $8);
							
					//generates labels	
					char* init_while = new_lbl();
					char* inside_while = new_lbl();
					char* out_while = new_lbl();
					
					iloc_op_list* temp = new_op_list();
					add_op(temp, label(init_while));
					$3->code = concat_code(temp, $3->code);
					$$->code = $3->code;					

					patch_list($3->code, $3->true_list, inside_while);
					patch_list($3->code, $3->false_list, out_while);

					add_op($$->code, label(inside_while));
					$$->code = concat_code($$->code, $8->code);
					add_op($$->code, jumpi(init_while));
										
					//false ->out while
					add_op($$->code, label(out_while));
					add_op($$->code, new_nop());
				}

do_while 	: TK_PR_DO '{' push_table cmd_block
				TK_PR_WHILE '(' bool_expr ')'
				{
					$$ = new_node($1);
					add_node($$, new_node($2));
					add_node($$, $4);
					add_node($$, new_node($5));
					add_node($$, new_node($6));
					add_node($$, $7);
					add_node($$, new_node($8));

					//generates labels
					char* init_while = new_lbl();
					char* out_while = new_lbl();
					
					$$->code = new_op_list();
					add_op($$->code, label(init_while));
					$$->code = concat_code($$->code, $4->code);	

					patch_list($7->code, $7->true_list, init_while);
					patch_list($7->code, $7->false_list, out_while);
					$$->code = concat_code($$->code, $7->code);
					
					//false ->out while
					add_op($$->code, label(out_while));	
					add_op($$->code, new_nop());			
				}

continue 	: TK_PR_CONTINUE
				{
					$$ = new_node($1);
				}

break 		: TK_PR_BREAK
				{
					$$ = new_node($1);
				}

return 		: TK_PR_RETURN expr
				{
					$$ = new_node($1);
					add_node($$, $2);

					if (function.type != $2->type) {
						if (can_convert(function.type, $2->type) == FALSE) {
							set_error(ERR_WRONG_PAR_RETURN);
						} else {
							$2->conversion = get_conversion(function.type, $2->type);
						}
					} else {
						if (function.type == USER_TYPE) {
							if (strcmp(function.type_name, $2->user_type) != 0) {
								set_error(ERR_WRONG_PAR_RETURN);
							}
						}
					}

					$$->code = $2->code;
					add_op($$->code, storeai($2->result_reg, RET_VALUE_ADDRESS, "rfp"));
					//simple_free_code($2->code);
				}

for 		: TK_PR_FOR '(' cmd_for for_fst_list
						bool_expr ':'
						cmd_for for_scd_list
						'{' push_table cmd_block
				{
					$$ = new_node($1);
					add_node($$, new_node($2));
					add_node($$, $3);
					add_node($$, $4);
					add_node($$, $5);
					add_node($$, new_node($6));
					add_node($$, $7);
					add_node($$, $8);
					add_node($$, new_node($9));
					add_node($$, $11);

					simple_free_code($3->code);
					simple_free_code($4->code);
					simple_free_code($5->code);
					simple_free_code($7->code);
					simple_free_code($8->code);
					simple_free_code($11->code);
				}

cmd_for 	: cmd_ident cmd_fix_local_var
					{
						$$ = $1;
						add_node($$, $2);
						
						int declaration_line = is_declared_on_current_table($2->token->value.v_string);
						int param_type = get_param_type($2->token->value.v_string, function.args_counter, function.function_args);
						if(declaration_line != NOT_DECLARED || param_type != NOT_DECLARED) 
							set_error(ERR_DECLARED);
						else 
							add_local_var($1->type, $1->user_type, FALSE, FALSE, $2->token);

						simple_free_code($1->code);
						simple_free_code($2->code);
					}
				| cmd_ident cmd_fix_attr
					{
						$$ = $1;
						add_node($$, $2);
						
						char* type_name;
						int type = get_id_type($1->token->value.v_string, &type_name);

						if ($2->user_type != NULL)
							type = get_id_field_type(type_name, $2->user_type);

						if (type != $2->type) {
							if (can_convert(type, $2->type) == FALSE) {
								set_error(ERR_WRONG_TYPE);
							} else {
								$2->conversion = get_conversion(type, $2->type);
							}
						} else if (type == USER_TYPE) {
							if (strcmp(type_name, $1->user_type) != 0) {
								set_error(ERR_WRONG_TYPE);
							}
						}

						int category = get_category($1->token->value.v_string);
						if (category != id_category) {
							if ($1->type != USER_TYPE || id_category != USER_TYPE)
								switch (category) {
									case FUNCTION:
										set_error(ERR_FUNCTION); break;
									case USER_TYPE:
										set_error(ERR_USER); break;
									case ARRAY:
										set_error(ERR_VECTOR); break;
									default:
										set_error(ERR_VARIABLE); break;
								}
						}
						
						if($1->type == USER_TYPE && $2->type == STRING) {
							update_string_size($1->token, $2->token);							
						}

						simple_free_code($1->code);
						simple_free_code($2->code);
					}
				| cmd_ident cmd_fix_call
					{
						$$ = $1;
						add_node($$, $2);
						
						int num_args = get_func_num_params($1->token->value.v_string);
						int category = get_category($1->token->value.v_string);
						int* expected_types = get_func_params_types($1->token->value.v_string);

						if (category == FUNCTION) {
							if (num_args == func_call_param_counter) {
								int index;
								for (index = 0; index < num_args; index++) {
									if (expected_types[index] != function_arguments[index].type) {
										if (can_convert(expected_types[index], function_arguments[index].type) == FALSE) {
											set_error(ERR_WRONG_TYPE_ARGS);	
										} 
									}
								}
							} else if (num_args > func_call_param_counter) {
								set_error(ERR_MISSING_ARGS);
							} else {
								set_error(ERR_EXCESS_ARGS);
							}
						} else if (category == USER_TYPE) {
							set_error(ERR_USER);
						} else if (category == ARRAY) {
							set_error(ERR_VECTOR);
						} else {
							set_error(ERR_VARIABLE);
						}


						if ($2->type != NOT_DECLARED) {
							char* dummy;
							int func_type = get_id_type($1->token->value.v_string, &dummy);
							if (func_type != $2->type) {
								if (can_convert(func_type, $2->type) == FALSE) {
									set_error(ERR_WRONG_TYPE);
								}
							}
						}

						free(expected_types);
						free(function_arguments);
						function_arguments = NULL;
						func_call_param_counter = 0;

					}
				| type TK_IDENTIFICADOR var_end 
					{
						$$ = $1;
						add_node($$, new_node($2));
						add_node($$, $3);

						int declaration_line = is_declared_on_current_table($2->value.v_string);
						int param_type = get_param_type($2->value.v_string, function.args_counter, function.function_args);
						
						if(declaration_line != NOT_DECLARED || param_type != NOT_DECLARED){
							set_error(ERR_DECLARED);
						} else {
							add_local_var($1->type, NULL, FALSE, FALSE, $2);
						}

						if ($3->type != NOT_DECLARED) 
							if ($1->type == $3->type) {
								if ($1->type == USER_TYPE)
									if (strcmp($1->user_type, $3->user_type) != 0)
										set_error(ERR_WRONG_TYPE);		
							} else 
								if (can_convert($1->type, $3->type) == FALSE) {
									set_error(ERR_WRONG_TYPE);
								} else {
									$3->conversion = get_conversion($1->type, $3->type);
								}
						if($3->token != NULL && $1->type == STRING && $3->type == STRING) {
							update_string_size($2, $3->token);
						}	

						simple_free_code($3->code);						
					}
				| TK_PR_STATIC static_var
					{
						$$ = new_node($1);
						add_node($$, $2);
					}
				| TK_PR_CONST const_var
					{
						$$ = new_node($1);
						add_node($$, $2);
					}
				| if_then 
					{
						$$ = $1;
					}
				| while 
					{
						$$ = $1;
					}
				| do_while 
					{
						$$ = $1;
					}
				| continue 
					{
						$$ = $1;
					}
				| break 
					{
						$$ = $1;
					}
				| return
					{
						$$ = $1;
					}
				| for 
					{
						$$ = $1;
					}
				| foreach
					{
						$$ = $1;
					}
				| switch
					{
						$$ = $1;
					}
				| input
					{
						$$ = $1;
					}
				| TK_PR_OUTPUT expr 
					{
						$$ = new_node($1);
						add_node($$, $2);

						simple_free_code($2->code);
					}
				| '{' push_table cmd_block 
					{
						$$ = new_node($1);
						add_node($$, $3);
					}

for_fst_list	: ',' cmd_for for_fst_list
					{
						$$ = new_node($1);
						add_node($$, $2);
						add_node($$, $3);
					}
				| ':'
					{
						$$ = new_node($1);
					}

for_scd_list	: ',' cmd_for for_scd_list
					{
						$$ = new_node($1);
						add_node($$, $2);
						add_node($$, $3);
					}
				| ')' 
					{
						$$ = new_node($1);
					}

foreach 	: TK_PR_FOREACH '(' TK_IDENTIFICADOR
							':' expr foreach_list
							'{' push_table cmd_block
					{
						$$ = new_node($1);
						add_node($$, new_node($2));
						add_node($$, new_node($3));
						add_node($$, new_node($4));
						add_node($$, $5);
						add_node($$, $6);
						add_node($$, new_node($7));
						add_node($$, $9);

						if ($6->type != IGNORE_TYPE) {
							if ($5->type == $6->type) {
								if ($5->type == USER_TYPE) {
									if ($5->user_type != NULL && $6->user_type != NULL) {
										if (strcmp($5->user_type, $6->user_type) == 0) {
											$$->type = USER_TYPE;
											$$->user_type = $5->user_type;
										} else {
											$$->type = INVALID_TYPE;
										}
									}
								} else {
									$$->type = $5->type;
									$$->user_type = NULL;
								}
							} else {
								$$->type = infer_without_error($5->type, $6->type);
							}	
						} else {
							$$->type = $5->type;
							$$->user_type = $5->user_type;
						}

						char* type_name;
						int var_type = get_id_type($3->value.v_string, &type_name);
						if ($$->type != var_type) {
							if (can_convert($$->type, var_type) == FALSE) {
								set_error(ERR_WRONG_TYPE);
							} else {
								$$->conversion = get_conversion(var_type, $$->type);
							}
						} else {
							if ($$->type == USER_TYPE) {
								if ($$->user_type != NULL && type_name != NULL) {
									if (strcmp($$->user_type, type_name) != 0)
										set_error(ERR_WRONG_TYPE); 
								}
							}
						}

						simple_free_code($5->code);
					}

foreach_list	: ',' foreach_count expr foreach_list 
					{
						$$ = new_node($1);
						add_node($$, $3);
						add_node($$, $4);

						if ($4->type != IGNORE_TYPE) {
							if ($3->type == $4->type) {
								if ($3->type == USER_TYPE) {
									if ($3->user_type != NULL && $4->user_type != NULL) {
										if (strcmp($3->user_type, $4->user_type) == 0) {
											$$->type = USER_TYPE;
											$$->user_type = $4->user_type;
										} else {
											$$->type = INVALID_TYPE;
										}
									}
								} else {
									$$->type = $3->type;
									$$->user_type = NULL;
								}
							} else {
								$$->type = infer_without_error($3->type, $4->type);
							}	
						} else {
							$$->type = $3->type;
							$$->user_type = $3->user_type;
						}

						if ($$->type == INVALID_TYPE)
							set_error(ERR_WRONG_TYPE);

						simple_free_code($3->code);
					}
				| ')' foreach_count
					{
						$$ = new_node($1);

						$$->type = IGNORE_TYPE;
					}

foreach_count	: %empty
					{}

switch 		: TK_PR_SWITCH '(' bool_expr ')' '{' push_table cmd_block
				{
					$$ = new_node($1);
					add_node($$, new_node($2));
					add_node($$, $3);
					add_node($$, new_node($4));
					add_node($$, new_node($5));
					add_node($$, $7);
				}

case 		: TK_PR_CASE expr ':'
				{
					$$ = new_node($1);
					add_node($$, $2);
					add_node($$, new_node($3));

					if ($2->type != INT) {
						if (can_convert(INT, $2->type) == FALSE) {
							set_error(ERR_WRONG_TYPE);
						} else {
							$2->conversion = get_conversion(INT, $2->type);
						}
					}

					simple_free_code($2->code);
				}

cmd_fix_local_var	: TK_IDENTIFICADOR
				{
					$$ = new_node($1);
				}
cmd_fix_attr		: id_seq_simple attr
				{
					$$ = new_node(NULL);
					add_node($$, $1);
					add_node($$, $2);
					set_node_type($$, $2->type);

					$$->token = copy_lexeme($2->token);	
					$$->user_type = $1->user_type;	

					$$->result_reg = $2->result_reg;
					$$->code = $2->code;
					$$->true_list = copy_label_list($2->true_list);	
					$$->false_list = copy_label_list($2->false_list);				
				}
cmd_fix_call		: '(' func_call_params piped_expr
				{
					$$ = new_node($1);
					add_node($$, $2);
					add_node($$, $3);

					$$->type = $3->type;
				}

static_var	: TK_PR_CONST const_var
				{
					$$ = new_node($1);
					add_node($$, $2);

					$$->code = $2->code;
				}
			| const_var 
				{
					$$ = $1;
				}
			
const_var	: type TK_IDENTIFICADOR var_end
				{
					$$ = $1;
					add_node($$, new_node($2));
					add_node($$, $3);

					$$->code = $3->code;
				}
			| TK_IDENTIFICADOR TK_IDENTIFICADOR
				{
					$$ = new_node($1);
					add_node($$, new_node($2));
				}

var_end 	: TK_OC_LE var_lit
				{
					$$ = new_node(NULL);
					add_node($$, new_node($1));
					add_node($$, $2);;
					$$->type = $2->type;
					$$->user_type = $2->user_type;

					$$->token = copy_lexeme($2->token);

					$$->code = $2->code;
					$$->result_reg = $2->result_reg;

				}
			| %empty
				{
					$$ = new_node(NULL);
					$$->type = NOT_DECLARED;
					$$->user_type = NULL;
				}

var_lit		: TK_IDENTIFICADOR
				{
					char** trash = malloc(sizeof(char**));
					$$ = new_node($1);
					$$->type = get_id_type($1->value.v_string, trash);
					$$->user_type = $1->value.v_string;
					$$->token = $1;

					$$->code = new_op_list();
					$$->result_reg = new_reg();
					char* displacement_reg = get_base_reg($1->value.v_string);
					//printf("Result_Reg [%s]\n", $$->result_reg);
					//printf("Displacement_reg [%s]\n", displacement_reg);
					//printf("Address [%s] = %d\n", $$->token->value.v_string, get_mem_address($$->token));
					add_op($$->code, loadai(displacement_reg, get_mem_address($$->token), $$->result_reg));
				}
			| TK_LIT_INT
				{
					$$ = new_node($1);
					$$->type = INT;
					$$->user_type = NULL;

					$$->result_reg = new_reg();
					$$->code = new_op_list();
					add_op($$->code, loadi($$->token->value.v_int, $$->result_reg));					
				}
			| TK_LIT_FLOAT
				{
					$$ = new_node($1);
					$$->type = FLOAT;
					$$->user_type = NULL;
				}
			| TK_LIT_CHAR
				{
					$$ = new_node($1);
					$$->type = CHAR;
					$$->user_type = NULL;
				}
			| TK_LIT_STRING
				{
					$$ = new_node($1);
					$$->type = STRING;
					$$->user_type = NULL;
					$$->token = $1;
				}
			| TK_LIT_TRUE
				{
					$$ = new_node($1);
					$$->type = BOOL;
					$$->user_type = NULL;
				}
			| TK_LIT_FALSE	
				{
					$$ = new_node($1);
					$$->type = BOOL;
					$$->user_type = NULL;
				}

attr 		: '=' expr
				{
					$$ = new_node(NULL);
					add_node($$, new_node($1));
					add_node($$, $2);
					set_node_type($$, $2->type);

					$$->token = copy_lexeme($2->token);
					$$->result_reg = $2->result_reg;
					$$->code = $2->code;
					//print_code($$->code);
					//printf("\nA\n");		
					$$->true_list = copy_label_list($2->true_list);	
					$$->false_list = copy_label_list($2->false_list);							
				}
			| TK_OC_SL expr 
				{
					$$ = new_node($1);
					add_node($$, $2);

					simple_free_code($2->code);
				}
			| TK_OC_SR expr 
				{
					$$ = new_node($1);
					add_node($$, $2);

					simple_free_code($2->code);
				}
			| pipe un_op TK_IDENTIFICADOR '(' func_call_params piped_expr 
				{
					$$ = $1;
					add_node($$, $2);
					add_node($$, new_node($3));
					add_node($$, new_node($4));
					add_node($$, $5);
					add_node($$, $6);
				}

piped_expr	: pipe un_op TK_IDENTIFICADOR '(' func_call_params piped_expr
				{
					$$ = $1;
					add_node($$, $2);
					add_node($$, new_node($3));
					add_node($$, new_node($4));
					add_node($$, $5);
					add_node($$, $6);

					int declaration_line = is_declared($3->value.v_string);
					if (declaration_line == NOT_DECLARED)
						set_error(ERR_UNDECLARED);

					int category = get_category($3->value.v_string);
					if (category != FUNCTION) {
						if (category == VARIABLE)
							set_error(ERR_VARIABLE);
						else if (category == ARRAY)
							set_error(ERR_VECTOR);
						else if (category == USER_TYPE)
							set_error(ERR_USER);
					}

					int point = func_call_param_counter - $5->point -1;
					if (point >= 0) {
						int num_expected_args = get_func_num_params($3->value.v_string);
						int* expected_types = get_func_params_types($3->value.v_string);
						if (point < num_expected_args) {
							$$->type = expected_types[point];
						}
						free(expected_types);
					}

					char* dummy;
					int func_type = get_id_type($3->value.v_string, &dummy);
						
					if ($6->type != NOT_DECLARED) {
						if (func_type != $6->type) {
							if (can_convert(func_type, $6->type) == FALSE) {
								set_error(ERR_WRONG_TYPE);
							}
						}
					} else {
						last_piped_function_type = func_type;
						last_piped_function_type_name = dummy;
					}

					func_call_param_counter = first_call_num_params;
				}
			| %empty 
				{
					$$ = new_node(NULL);
					$$->point = -1;
					$$->type = NOT_DECLARED;
				}

un_op 			: not_null_un_op un_op
					{
						$$ = $1;
						add_node($$, $2);
					}
				| %empty
					{
						$$ = new_node(NULL);
					}

not_null_un_op  : '+' 
					{
						$$ = new_node($1);
					}
				| '-'
					{
						$$ = new_node($1);
					} 
				| '!'
					{
						$$ = new_node($1);
					} 
				| '&'
					{
						$$ = new_node($1);
					} 
				| '*'
					{
						$$ = new_node($1);
					} 
				| '?'
					{
						$$ = new_node($1);
					} 
				| '#'
					{
						$$ = new_node($1);
					}

expr 			: expr '+' expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = $1->type;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = type;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}

						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							if ($1->code != NULL && $3->code != NULL) {
								$$->code = concat_code($1->code, $3->code);
								$$->result_reg = new_reg();
								add_op($$->code, add($1->result_reg, $3->result_reg, $$->result_reg));
							} else {
								simple_free_code($1->code);
								simple_free_code($3->code);
							}
						} else {
							simple_free_code($1->code);
							simple_free_code($3->code);
						}
					}
				| expr '-' expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = $1->type;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = type;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}

						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							if ($1->code != NULL && $3->code != NULL) {
								$$->code = concat_code($1->code, $3->code);
								$$->result_reg = new_reg();
								add_op($$->code, sub($1->result_reg, $3->result_reg, $$->result_reg));
							} else {
								simple_free_code($1->code);
								simple_free_code($3->code);
							}
						} else {
							simple_free_code($1->code);
							simple_free_code($3->code);
						}
					}
				| expr '*' expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = $1->type;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = type;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}
						
						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							if ($1->code != NULL && $3->code != NULL) {
								$$->code = concat_code($1->code, $3->code);
								$$->result_reg = new_reg();
								add_op($$->code, mult($1->result_reg, $3->result_reg, $$->result_reg));
							} else {
								simple_free_code($1->code);
								simple_free_code($3->code);
							}
						} else {
							simple_free_code($1->code);
							simple_free_code($3->code);
						}
					}
				| expr '/' expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = $1->type;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = type;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}

						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							if ($1->code != NULL && $3->code != NULL) {
								$$->code = concat_code($1->code, $3->code);
								$$->result_reg = new_reg();
								add_op($$->code, div_op($1->result_reg, $3->result_reg, $$->result_reg));
							}
						}
					}
				| expr '%' expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = $1->type;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = type;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}
					}
				| expr '^' expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = $1->type;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = type;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}
					}
				| expr '|' expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = BOOL;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = type;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}
					}
				| expr '&' expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = BOOL;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = type;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}
					}
				| expr '>' expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = BOOL;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = BOOL;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}

						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							$$->false_list = new_label_list();
							$$->true_list = new_label_list();

							char* lbl_false = new_lbl();
							add_label_to_list($$->false_list, lbl_false);
							char* lbl_true = new_lbl();
							add_label_to_list($$->true_list, lbl_true);
													
							$$->code = concat_code($1->code, $3->code);
							$$->result_reg = new_reg();
							add_op($$->code, cmp_gt($1->result_reg, $3->result_reg, $$->result_reg));
							add_op($$->code, cbr($$->result_reg, lbl_true, lbl_false));
						} else {
							simple_free_code($1->code);
							simple_free_code($3->code);
						}
					}
				| expr '<' expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = BOOL;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = BOOL;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}
						
						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							$$->false_list = new_label_list();
							$$->true_list = new_label_list();

							char* lbl_false = new_lbl();
							add_label_to_list($$->false_list, lbl_false);
							char* lbl_true = new_lbl();
							add_label_to_list($$->true_list, lbl_true);
													
							$$->code = concat_code($1->code, $3->code);
							$$->result_reg = new_reg();
							add_op($$->code, cmp_lt($1->result_reg, $3->result_reg, $$->result_reg));
							add_op($$->code, cbr($$->result_reg, lbl_true, lbl_false));
						} else {
							simple_free_code($1->code);
							simple_free_code($3->code);
						}
					}
				| expr TK_OC_AND expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = BOOL;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = type;
						}

						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							char* new_label = new_lbl();
							//$$->result_reg  = new_reg();

							patch_list($1->code, $1->true_list, new_label);
							$$->true_list = copy_label_list($3->true_list);
							$$->false_list = concat_labels($1->false_list, $3->false_list);

							$$->code = new_op_list();
							add_op($$->code, label(new_label));
							//print_code($1->code);
							$$->code = concat_code($1->code, $$->code);
							$$->code = concat_code($$->code, $3->code);
						} else {
							simple_free_code($1->code);
							simple_free_code($3->code);
						}						

					}
				| expr TK_OC_OR expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = BOOL;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = BOOL;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}

						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							char* new_label = new_lbl();
							//$$->result_reg  = new_reg();

							patch_list($1->code, $1->false_list, new_label);
							$$->false_list = copy_label_list($3->false_list);
							$$->true_list = concat_labels($1->true_list, $3->true_list);

							$$->code = new_op_list();
							add_op($$->code, label(new_label));
							//print_code($1->code);
							$$->code = concat_code($1->code, $$->code);
							$$->code = concat_code($$->code, $3->code);
						} else {
							simple_free_code($1->code);
							simple_free_code($3->code);
						}
					}
				| expr TK_OC_LE expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = BOOL;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = BOOL;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}
						
						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							$$->false_list = new_label_list();
							$$->true_list = new_label_list();

							char* lbl_false = new_lbl();
							add_label_to_list($$->false_list, lbl_false);
							char* lbl_true = new_lbl();
							add_label_to_list($$->true_list, lbl_true);
							
							$$->code = concat_code($1->code, $3->code);
							$$->result_reg = new_reg();
							add_op($$->code, cmp_le($1->result_reg, $3->result_reg, $$->result_reg));
							add_op($$->code, cbr($$->result_reg, lbl_true, lbl_false));
						} else {
							simple_free_code($1->code);
							simple_free_code($3->code);
						}
					}
				| expr TK_OC_NE expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = BOOL;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = BOOL;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}

						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							$$->false_list = new_label_list();
							$$->true_list = new_label_list();

							char* lbl_false = new_lbl();
							add_label_to_list($$->false_list, lbl_false);
							char* lbl_true = new_lbl();
							add_label_to_list($$->true_list, lbl_true);
							
							$$->code = concat_code($1->code, $3->code);
							$$->result_reg = new_reg();
							add_op($$->code, cmp_ne($1->result_reg, $3->result_reg, $$->result_reg));
							add_op($$->code, cbr($$->result_reg, lbl_true, lbl_false));
						} else {
							simple_free_code($1->code);
							simple_free_code($3->code);
						}
					}
				| expr TK_OC_EQ expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = BOOL;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = BOOL;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}

						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							$$->false_list = new_label_list();
							$$->true_list = new_label_list();
							
							char* lbl_false = new_lbl();
							add_label_to_list($$->false_list, lbl_false);
							char* lbl_true = new_lbl();
							add_label_to_list($$->true_list, lbl_true);
							
							$$->code = concat_code($1->code, $3->code);
							$$->result_reg = new_reg();
							add_op($$->code, cmp_eq($1->result_reg, $3->result_reg, $$->result_reg));
							add_op($$->code, cbr($$->result_reg, lbl_true, lbl_false));
						} else {
							simple_free_code($1->code);
							simple_free_code($3->code);
						}
					}
				| expr TK_OC_GE expr
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, new_node($2));
						add_node($$, $3);

						if ($1->type == $3->type) {
							$$->type = BOOL;
						} else {
							int type = infer($1->type, $3->type);
							$$->type = BOOL;

							if ($1->type == type) {
								$3->conversion = get_conversion(type, $3->type);
							} else {
								$1->conversion = get_conversion(type, $1->type);
							}
						}
						
						if (($1->type == INT || $1->type == BOOL)
							&& ($3->type == INT || $3->type == BOOL)) {
							$$->false_list = new_label_list();
							$$->true_list = new_label_list();

							char* lbl_false = new_lbl();
							add_label_to_list($$->false_list, lbl_false);
							char* lbl_true = new_lbl();
							add_label_to_list($$->true_list, lbl_true);
							
							$$->code = concat_code($1->code, $3->code);
							$$->result_reg = new_reg();
							add_op($$->code, cmp_ge($1->result_reg, $3->result_reg, $$->result_reg));
							add_op($$->code, cbr($$->result_reg, lbl_true, lbl_false));
						} else {
							simple_free_code($1->code);
							simple_free_code($3->code);
						}
					}
				| un_op expr_vals
					{
						$$ = new_node(NULL);
						add_node($$, $1);
						add_node($$, $2);
						set_node_type($$, $2->type);
						$$->user_type = $2->user_type;

						$$->is_literal = $2->is_literal;

						$$->token = copy_lexeme($2->token);	

						$$->code = $2->code;
						$$->result_reg = $2->result_reg;					
					}

expr_vals		: TK_LIT_FLOAT
					{
						$$ = new_node($1);
						set_node_type($$, FLOAT);
						$$->is_literal = TRUE;
					}
				| TK_LIT_INT
					{

						$$ = new_node($1);
						set_node_type($$, INT);
						$$->is_literal = TRUE;

						$$->result_reg = new_reg();
						$$->code = new_op_list();
						add_op($$->code, loadi($$->token->value.v_int, $$->result_reg));	
					}
				| id_for_expr id_seq 
					{
						$$ = $1;
						add_node($$, $2);
						//add_node($$, $3);

						int category = get_category($1->token->value.v_string);
						if (get_param_type($1->token->value.v_string, function.args_counter, function.function_args) == NOT_DECLARED) {
							if (category != id_category) {
								if ($1->type != USER_TYPE)
									switch (category) {
										case FUNCTION:
											set_error(ERR_FUNCTION); break;
										case USER_TYPE:
											set_error(ERR_USER); break;
										case ARRAY:
											set_error(ERR_VECTOR); break;
										default:
											set_error(ERR_VARIABLE); break;
									}
							}
						}

						if (id_category == FUNCTION) {
							$$->code = new_op_list();
							$$->result_reg = new_reg();
							int num_args = get_func_num_params($1->token->value.v_string);
							int* expected_types = get_func_params_types($1->token->value.v_string);

							if (num_args == func_call_param_counter) {
								int index;
								for (index = 0; index < num_args; index++) {
									if (expected_types[index] != function_arguments[index].type) {
										if (can_convert(expected_types[index], function_arguments[index].type) == FALSE)
											set_error(ERR_WRONG_TYPE_ARGS);	
									}
								}
							} else if (num_args > func_call_param_counter) {
								set_error(ERR_MISSING_ARGS);
							} else {
								set_error(ERR_EXCESS_ARGS);
							}

							char* reg_return = new_reg();
							if ($2->code != NULL) {
								$$->code = concat_code($$->code, $2->code);
							}
							add_op($$->code, addi("rpc", 5+func_call_param_counter, reg_return));
							add_op($$->code, storeai(reg_return, RETURN_ADDRESS, "rsp"));
							add_op($$->code, storeai("rsp", OLD_RSP, "rsp"));
							add_op($$->code, storeai("rfp", OLD_RFP, "rsp"));


							if (func_call_param_counter > 0) {
								for (int i = 0; i < func_call_param_counter; i++) {
									add_op($$->code, storeai($2->param_regs[i], BEGIN_OF_PARAMS+(i*4), "rsp"));
								}
							}
							add_op($$->code, jumpi(get_function_label($1->token->value.v_string)));
							add_op($$->code, loadai("rsp", RET_VALUE_ADDRESS, $$->result_reg));

							free(expected_types);
							free(function_arguments);
							function_arguments = NULL;
							func_call_param_counter = 0;
						} else {
							$$->code = new_op_list();
							$$->result_reg = new_reg();
							char* in_function = function.lexeme->value.v_string;
							char* displacement_reg;
							int displacement_param = get_parameter_index(in_function, $1->token->value.v_string);
							if (displacement_param != -1) {
								displacement_reg = "rfp";
								add_op($$->code, loadai(displacement_reg, 16 + displacement_param*4, $$->result_reg));
							} else {
								displacement_reg = get_base_reg($1->token->value.v_string);
								//printf("\nS = %s", $$->token->value.v_string);
								add_op($$->code, loadai(displacement_reg, get_mem_address($$->token), $$->result_reg));
							}
						}

						if (category == USER_TYPE)
							set_error(ERR_USER);

						if($2->user_type != NULL) {
							char* type_name;
							int id_type = get_id_type($1->token->value.v_string, &type_name);
							if (type_name != NULL) {
								int type = get_id_field_type(type_name, $2->user_type);
								if (type == INVALID_FIELD) {
									set_error(ERR_UNDECLARED);
								} else {
									$$->type = type;
								}
							}
						} 

						if (last_piped_function_type != NOT_DECLARED) {
							$$->type = last_piped_function_type;
							$$->user_type = last_piped_function_type_name;
							last_piped_function_type = NOT_DECLARED;
							last_piped_function_type_name = NULL;
						}

						// Reset id_category
						id_category = VARIABLE;

					}
				| TK_LIT_CHAR 
					{
						$$ = new_node($1);
						set_node_type($$, CHAR);
						$$->is_literal = TRUE;
					}
				| TK_LIT_STRING 
					{
						$$ = new_node($1);
						set_node_type($$, STRING);
						$$->is_literal = TRUE;
						$$->token = $1;						
					}
				|'(' expr ')' 
					{
						$$ = new_node(NULL);
						add_node($$, new_node($1));
						add_node($$, $2);
						add_node($$, new_node($3));

						$$->type = $2->type;
						$$->user_type = $2->user_type;

						$$->result_reg = $2->result_reg;
						$$->code = $2->code;
						//add_op($$->code, loadi($$->token->value.v_int, $$->result_reg));	
					}
				| bool
					{
						$$ = $1;
						set_node_type($$, BOOL);
						$$->is_literal = TRUE;
					}

id_for_expr		: TK_IDENTIFICADOR
					{

						$$ = new_node($1);

						id_category = VARIABLE;

						int is_id_declared = NOT_DECLARED;
						int type = NOT_DECLARED;

						int param_type = get_param_type($1->value.v_string, function.args_counter, function.function_args);
						if (param_type == NOT_DECLARED) {
							
							is_id_declared = is_declared($1->value.v_string);
							if (is_id_declared == NOT_DECLARED)
								set_error(ERR_UNDECLARED);

							char* type_name;
							type = get_id_type($1->value.v_string, &type_name);

							$$->type = type;
							$$->user_type = type_name;
						} else {
							$$->type = param_type;
						}	
						
					}

/*piped 			: %empty
					{
						$$ = new_node(NULL);
					}
				| pipe TK_IDENTIFICADOR id_seq piped_expr
					{
						$$ = $1;
						add_node($$, new_node($2));
						add_node($$, $3);
						add_node($$, $4);
					}*/

id_seq			:  id_seq_simple
					{
						$$ = $1;						
					}
				| '(' func_call_params piped_expr
					{
						$$ = new_node($1);
						add_node($$, $2);
						add_node($$, $3);

						id_category = FUNCTION;

						$$->code = $2->code;
						$$->num_param_regs = $2->num_param_regs;
						$$->param_regs = $2->param_regs;
					} 

id_seq_field 	: '$' TK_IDENTIFICADOR  
					{
						$$ = new_node(NULL);
						add_node($$, new_node($1));
						add_node($$, new_node($2));

						id_category = USER_TYPE;

						$$->user_type = $2->value.v_string;
					}
				| %empty
					{
						$$ = new_node(NULL);
						$$->user_type = NULL;
					}

id_seq_simple	: '[' expr ']' id_seq_field
					{
						$$ = new_node(NULL);
						add_node($$, new_node($1));
						add_node($$, $2);
						add_node($$, new_node($3));
						add_node($$, $4);

						if ($2->type != INT) {
							if (can_convert(INT, $2->type) == FALSE) {
								set_error(ERR_WRONG_TYPE);
							} else {
								$2->conversion = get_conversion(INT, $2->type);
							}
						}

						id_category = ARRAY;

						$$->user_type = $4->user_type;

						simple_free_code($2->code);
					} 
				|  id_seq_field
					{
						$$ = $1;											
					}

func_call_params	: ')' 
						{	
							$$ = new_node($1);
						}
					| expr func_call_params_body
						{
							$$ = $1;
							add_node($$, $2);

							if (func_call_param_counter == 0) {
								function_arguments = malloc(sizeof(func_call_arg));
							} else {
								function_arguments = realloc(function_arguments, (func_call_param_counter+1)*sizeof(func_call_arg));
							}
							function_arguments[func_call_param_counter].type = $1->type;
							function_arguments[func_call_param_counter].user_type = $1->user_type;

							$$->point = $2->point;
							func_call_param_counter++;

							if ($2->code != NULL)
								$$->code = concat_code($$->code, $2->code);

							add_param_reg($$, $1->result_reg);
							if ($2->num_param_regs > 0) {
								for (int i = 0; i < $2->num_param_regs; i++) {
									add_param_reg($$, $2->param_regs[i]);
								}
							}

							/*printf("\nIUOUOU1 = %s", $1->result_reg);
							printf("\nIUOUOU2 = %s", $$->children[1]->result_reg);*/

							/* Will be removed */	
							//simple_free_code($1->code);
						}
					| '.' func_call_params_body
						{
							$$ = new_node($1);
							add_node($$, $2);

							if (func_call_param_counter == 0) {
								function_arguments = malloc(sizeof(func_call_arg));
							} else {
								function_arguments = realloc(function_arguments, (func_call_param_counter+1)*sizeof(func_call_arg));
							}
							function_arguments[func_call_param_counter].type = NOT_DECLARED;
							function_arguments[func_call_param_counter].user_type = NULL;
							
							$$->point = func_call_param_counter;
							func_call_param_counter++;
						}

func_call_params_body 	: ')' 
						{
							$$ = new_node($1);
							$$->point = -1;


						}
						| ',' func_call_params_end
						{
							$$ = new_node($1);
							add_node($$, $2);
							$$->point = $2->point;
							$$->code = $2->code;

							$$->param_regs = $2->param_regs;
							$$->num_param_regs = $2->num_param_regs;

							//$$->result_reg = $2->result_reg;

						}

func_call_params_end 	: expr func_call_params_body
							{
								$$ = $1;
								add_node($$, $2);

								if (func_call_param_counter == 0) {
									function_arguments = malloc(sizeof(func_call_arg));
								} else {
									function_arguments = realloc(function_arguments, (func_call_param_counter+1)*sizeof(func_call_arg));
								}
								function_arguments[func_call_param_counter].type = $1->type;
								function_arguments[func_call_param_counter].user_type = $1->user_type;

								$$->point = $2->point;
								func_call_param_counter++;

								add_param_reg($$, $1->result_reg);
								if ($2->num_param_regs > 0) {
									for(int i = 0; i < $2->num_param_regs; i++) {
										add_param_reg($$, $2->param_regs[i]);
									}
								}	

								if ($2->code != NULL)
									$$->code = concat_code($$->code, $2->code);

								/* Will be removed */
								//simple_free_code($1->code);
							}
						| '.' func_call_params_body
							{
								
								$$ = new_node($1);
								add_node($$, $2);

								if (func_call_param_counter == 0) {
									function_arguments = malloc(sizeof(func_call_arg));
								} else {
									function_arguments = realloc(function_arguments, (func_call_param_counter+1)*sizeof(func_call_arg));
								}
								function_arguments[func_call_param_counter].type = NOT_DECLARED;
								function_arguments[func_call_param_counter].user_type = NULL;

								$$->point = func_call_param_counter;
								func_call_param_counter++;
							}

%%

void yyerror(char const *s) {
    fprintf(stderr,"ERROR: line %d - %s\n", yylineno, s);
}

int infer(int type_a, int type_b) {
	int inferred = infer_without_error(type_a, type_b);
	if (inferred == INVALID_TYPE) {
		if (type_a == CHAR || type_b == CHAR) set_error(ERR_CHAR_TO_X);
		else if (type_a == STRING || type_b == STRING) set_error(ERR_STRING_TO_X);
		else if (type_a == USER_TYPE || type_b == USER_TYPE) set_error(ERR_USER_TO_X);
	}
	return inferred;
}