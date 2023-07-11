
// Testar se funciona corretamente o empilhamento de par�metros
// passados por valor ou por refer�ncia.

/*
Alunos:
    Wendel Caio Moro GRR20182641
    Bruno Augusto Luvizott GRR20180112
    Atualizado em: [23/02/2022]
*/

%{
#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include "compilador.h"
#include "stack.h"

#define MAX_SYMBOL_SIZE 32

enum variavel_tipos { 
    INTEGER = 0,
    BOOLEAN,
} tipos;

enum definition { 
    SIMPLE_VARIABLE = 0,
    IS_PROCEDURE,
    FORMAL_PARAM,
    IS_FUNCTION,
} definition;

enum param_declaration { 
    BY_VALUE = 0,
    BY_REFERENCE,
} param_declaration;

int num_vars = 0;
int lex_level = 0;
int offset = 0;

identType last_ident;

// symbols table represented as an array
Symbol symbolsTable[255];
int tablePosition = -1;

stack *auxStack;
stack *assignVariables;
stack *labels;
stack *procedureLabels;

int hasBoolExpression = 0;
int hasIntExpression = 0;

int assignDetected = 0;

int labelNumber = 0;

int needWrite = 0;
int needRead = 0;
int ifExpression = 0;
int whileExpression = 0;
int comparativeExpression = 0;

/* Variáveis usadas para auxiliar nos procedimentos */
int haveProcedures = 0;
int countProcedures = 0;
int procedureCall = 0;
int procedureWithParams = 0;
char lastProcSymbol[64];
int countProcedureParams = 0;
int composedExpression = 0;
int constantVal = 0;
int passedByReference = 0;

int lastProcedureTableIndex = -1;
int shouldCheckParams = 0;
int paramIndex = 0;
int totalParams = 0;
char procedureTokenCheck[255];

%}

%token PROGRAM ABRE_PARENTESES FECHA_PARENTESES
%token VIRGULA PONTO_E_VIRGULA DOIS_PONTOS PONTO
%token T_BEGIN T_END VAR IDENT ATRIBUICAO
%token ARRAY PROCEDURE FUNCTION WHILE
%token DIVISAO_REAL DIVISAO ADICAO SUBTRACAO MULTIPLICACAO
%token MOD AND OR XOR DIFERENTE IGUAL
%token MAIOR MENOR MAIOR_IGUAL MENOR_IGUAL IN
%token HASH ASPA_SIMPLES CIFRAO INTERVALO ABRE_COLCHETES
%token FECHA_COLCHETES ABRE_CHAVES FECHA_CHAVES
%token NUMERO VERDADEIRO FALSO DO WRITE READ
%token IF THEN ELSE FORWARD

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

programa    :{
                geraCodigo (NULL, "INPP");
             }
             PROGRAM IDENT
             ABRE_PARENTESES lista_idents FECHA_PARENTESES PONTO_E_VIRGULA 
             bloco  PONTO {
                geraCodigo (NULL, "PARA");
             }
;

bloco       : parte_declara_vars subrotinas
            comando_composto {
                if (tablePosition >= 0) {
                    int count = 0;
                    int haveProcedure = 0;
                    char output[64];

                    for (int i = tablePosition; i >= 0; i--) {
                        if ((symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && symbolsTable[i].lex_level == lex_level) {
                            haveProcedure = 1;
                            break;
                        }

                        if (symbolsTable[i].def == SIMPLE_VARIABLE && symbolsTable[i].lex_level == lex_level) {
                            count++;
                        }
                    }
                    
                    if (count > 0) {
                        sprintf(output,"DMEM %d", count);
                        geraCodigo (NULL, output);
                    }

                    if (haveProcedure) {
                        tablePosition -= count;
                    }
                    else {
                        tablePosition = -1;
                    }
                }

            }
;

parte_declara_vars:  var
;

var         : { } VAR declara_vars
            |
;

declara_vars: declara_vars declara_var { 
                    num_vars = 0;
            }
            | declara_var { 
                num_vars = 0;
            }
;

declara_var :   lista_id_var DOIS_PONTOS
                tipo {
                    if (num_vars > 0) {
                        char output[64];
                        sprintf(output,"AMEM %d",num_vars);
                        geraCodigo (NULL, output);
                    }

                    num_vars = 0;
                }
                PONTO_E_VIRGULA
;

tipo        : IDENT {                                
                int index = tablePosition;
                int count = 0;

                while(count < num_vars) {
                    if (strcmp(token, "integer") == 0) {
                        symbolsTable[index].type = INTEGER;
                    }
                    else if (strcmp(token, "boolean") == 0) {
                        symbolsTable[index].type = BOOLEAN;
                    }
                    else {
                        char output[64];
                        sprintf(output, "unidentified type '%s'", token);
                        imprimeErro(output);
                    }

                    index--;
                    count++;
                }
            }
;

lista_id_var: lista_id_var VIRGULA IDENT { 
                /* insere �ltima vars na tabela de s�mbolos */                 
                char output[64];

                // Checa se símbolo já está declarado na tabela de símbolos
                for (int i = tablePosition; i >= 0; i--) {
                    if (strcmp(token, symbolsTable[i].symbol) == 0 && symbolsTable[i].lex_level == lex_level) {
                        sprintf(output, "symbol '%s'  already declared", token);
                        imprimeErro(output);
                    }

                    if (strcmp(token, symbolsTable[i].symbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && symbolsTable[i].lex_level <= lex_level) {
                        sprintf(output, "symbol '%s'  already declared as a procedure", token);
                        imprimeErro(output);
                    }
                }
                tablePosition++;
                strcpy(symbolsTable[tablePosition].symbol, token);
                symbolsTable[tablePosition].lex_level = lex_level;
                symbolsTable[tablePosition].offset = offset;
                symbolsTable[tablePosition].def = SIMPLE_VARIABLE;
 
                offset++;
                num_vars++;
              }
            | IDENT { 
                /* insere vars na tabela de s�mbolos */            
                tablePosition++;
                strcpy(symbolsTable[tablePosition].symbol, token);
                symbolsTable[tablePosition].lex_level = lex_level;
                symbolsTable[tablePosition].offset = offset;
                symbolsTable[tablePosition].def = SIMPLE_VARIABLE;    

                offset++;
                num_vars++;
            }
;

atribuicao: variavel ATRIBUICAO constante {
                char output[64];
                int index = tablePosition;

                if (!assignVariables->top->isFunction) {
                    sprintf(output, "cannot assign expressions to procedures\n");
                    imprimeErro(output);
                }

                if (assignVariables->top->type != auxStack->top->type) {
                    sprintf(output, "trying to assign value of different type to variable '%s'\n", assignVariables->top->symbol);
                    imprimeErro(output);
                }

                while(strcmp(symbolsTable[index].symbol, last_ident.token) != 0) {
                    if (index < 0) {
                        break;
                    }     
                    index--;               
                }

                if (index >= 0) {
                    if (symbolsTable[index].by_reference) {
                        sprintf(output,"ARMI %d, %d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    }
                    else {
                        sprintf(output,"ARMZ %d, %d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    }
                    geraCodigo (NULL, output);
                }
                else {
                    sprintf(output, "symbol not declared '%s' identified\n", last_ident.token);
                    imprimeErro(output);
                }

                pop(assignVariables);

                pop(auxStack);
                pop(auxStack);
                

                assignDetected = 0;
            }
            | variavel ATRIBUICAO variavel {
                node *aux = auxStack->top;
                int index = tablePosition;
                char output[64];

                if (!assignVariables->top->isFunction) {
                    sprintf(output, "cannot assign expressions to procedures\n");
                    imprimeErro(output);
                }

                if (procedureCall) {
                    sprintf(output, "trying to assign procedure to variable '%s'\n", aux->symbol);
                    imprimeErro(output);
                }

                if (assignVariables->top->type != aux->type) {
                    sprintf(output, "trying to assign value of different type to variable '%s'\n", assignVariables->top->symbol);
                    imprimeErro(output);
                }
                aux = aux->previous;
                while (index >= 0) {
                    if (strcmp(symbolsTable[index].symbol, aux->symbol) == 0 && symbolsTable[index].lex_level <= lex_level) {
                        break;
                    }

                    index--;
                }

                if (index >= 0) {
                    if (symbolsTable[index].by_reference) {
                        sprintf(output,"ARMI %d, %d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    }
                    else {
                        sprintf(output,"ARMZ %d, %d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    }
                    geraCodigo (NULL, output);
                }
                else {
                    sprintf(output, "symbol not declared '%s' identified\n", last_ident.token);
                    imprimeErro(output);
                }
                pop(assignVariables);
                pop(auxStack);
                pop(auxStack);

                assignDetected = 0;
                procedureCall = 0;
            }
            | variavel ATRIBUICAO expressao {
                char output[64];
                int index = tablePosition;

                if (!assignVariables->top->isFunction) {
                    sprintf(output, "cannot assign expressions to procedures\n");
                    imprimeErro(output);
                }

                if (!auxStack->top->isFunction) {
                    sprintf(output, "trying to assign procedure to variable '%s'\n", assignVariables->top->symbol);
                    imprimeErro(output);
                }
                
                if (hasBoolExpression) {
                    if (assignVariables->top->type != BOOLEAN) {
                        sprintf(output, "trying to assign BOOLEAN expression to variable '%s' of type INTEGER\n", assignVariables->top->symbol);
                        imprimeErro(output);
                    }
                }
                if (assignVariables->top->type == BOOLEAN && !hasBoolExpression) {
                        sprintf(output, "trying to assign NOT BOOLEAN value to variable '%s' of type BOOLEAN\n", assignVariables->top->symbol);
                        imprimeErro(output);
                }

                while (index >= 0) {
                    if (strcmp(symbolsTable[index].symbol, assignVariables->top->symbol) == 0 && symbolsTable[index].lex_level <= lex_level) {
                        break;
                    }

                    index--;
                }

                if (index >= 0) {
                    if (symbolsTable[index].by_reference) {
                        sprintf(output,"ARMI %d, %d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    }
                    else {
                        sprintf(output,"ARMZ %d, %d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    }
                    geraCodigo (NULL, output);
                }
                else {
                    sprintf(output, "symbol not declared '%s' identified\n", last_ident.token);
                    imprimeErro(output);
                }

                hasBoolExpression = 0;

                pop(assignVariables);

                assignDetected = 0;
                if (auxStack->bottom != NULL) {
                    pop(auxStack);
                }
            }
            | chamada_subrotina
;

variavel: IDENT {
            int index = tablePosition;
            char output[64];

            node *aux = malloc(sizeof(node));
            strcpy(aux->symbol, token);

            // busca o símbolo na tabela de símbolos para poder identificação
            while (index >= 0) {
                if ((strcmp(symbolsTable[index].symbol, token) == 0 && symbolsTable[index].lex_level <= lex_level && symbolsTable[index].def != IS_PROCEDURE && symbolsTable[index].def != IS_FUNCTION) 
                    || (strcmp(symbolsTable[index].symbol, token) == 0 && (symbolsTable[index].def == IS_PROCEDURE || symbolsTable[index].def == IS_FUNCTION) && symbolsTable[index].lex_level >= symbolsTable[index].lex_level)) {
                    break;
                }
                
                index--;
            }

            if (index >= 0) {                
                if (symbolsTable[index].def == IS_PROCEDURE || symbolsTable[index].def == IS_FUNCTION) {
                    procedureCall = 1;
                    if (symbolsTable[index].def == IS_FUNCTION) {
                        aux->isFunction = 1;
                    }
                    else {
                        aux->isFunction = 0;
                    }
                }
                else {
                    aux->isFunction = 1;
                    procedureCall = 0;
                    aux->type = symbolsTable[index].type;
                }
            }
            else {
                sprintf(output, "symbol not declared '%s' identified\n", aux->symbol);
                imprimeErro(output);
            }

            push(auxStack, aux);
            strcpy(last_ident.token, token);

            if (!assignDetected && symbolsTable[index].def == IS_FUNCTION) {
                sprintf(output,"AMEM 1");
                geraCodigo (NULL, output);
            }
            
            if (assignDetected) {
                node *aux2 = malloc(sizeof(node));
                aux2->type = auxStack->top->type;
                if (symbolsTable[index].def != IS_PROCEDURE) {
                    aux2->isFunction = 1;
                }
                else {
                    aux2->isFunction = 0;
                }
                strcpy(aux2->symbol, auxStack->top->symbol);

                push(assignVariables, aux2);
            }

            if (!assignDetected && !procedureCall) {
                aux = auxStack->top;

                index = tablePosition;
                while (index >= 0) {
                    if (strcmp(symbolsTable[index].symbol, aux->symbol) == 0 && symbolsTable[index].lex_level <= lex_level) {
                        break;
                    }
                    
                    index--;
                }

                if (index < 0) {
                    sprintf(output, "symbol not declared '%s' identified\n", aux->symbol);
                    imprimeErro(output);
                }

                int found = 0;
                int debug = 0;
                if (!assignDetected && !procedureWithParams && !procedureCall){
                    if (symbolsTable[index].by_reference == BY_VALUE){
                        sprintf(output,"CRVL %d, %d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    } else{
                        sprintf(output,"CRVI %d, %d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    }
                    geraCodigo (NULL, output);
                    debug = 1;
                }

                if (!debug) {
                    for (int i = tablePosition; i >= 0; i--) {
                        if (strcmp(symbolsTable[i].symbol, lastProcSymbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && 
                            (symbolsTable[i].lex_level <= lex_level || symbolsTable[i].lex_level == lex_level + 1)) {
                            
                            if (symbolsTable[i].params[symbolsTable[i].total_params - countProcedureParams].by_reference == BY_VALUE) {
                                for (int j = tablePosition; j >= 0; j--) {
                                    if (strcmp(aux->symbol, symbolsTable[j].symbol) == 0 && 
                                        (symbolsTable[j].lex_level <= lex_level || symbolsTable[j].lex_level == lex_level + 1)) {
                                            if (symbolsTable[j].by_reference == BY_VALUE) {
                                                sprintf(output,"CRVL %d, %d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                                                geraCodigo (NULL, output);
                                                found = 1;
                                                break;
                                            }
                                            else if (symbolsTable[j].by_reference == BY_REFERENCE) {
                                                sprintf(output,"CRVI %d, %d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                                                geraCodigo (NULL, output);
                                                found = 1;
                                                break;
                                            }
                                        }
                                }
                            }
                            
                        }

                        if (found) {
                            break;
                        }
                    }
                }
            }

            if (procedureCall) { 
                strcpy(lastProcSymbol, token);
            }

            assignDetected = 0;
        }
;

constante:  NUMERO {
                // empilha constante para poder identificar tipagem
                node *aux = malloc(sizeof(node));
                char output[64];

                strcpy(aux->symbol, token);
                aux->type = INTEGER;
                aux->isFunction = 1;
                push(auxStack, aux);

                sprintf(output,"CRCT %s", token);
                geraCodigo (NULL, output);
            }
            | FALSO {
                // empilha constante para poder identificar tipagem
                node *aux = malloc(sizeof(node));
                char output[64];

                strcpy(aux->symbol, token);
                aux->type = BOOLEAN;
                aux->isFunction = 1;
                push(auxStack, aux);

                sprintf(output,"CRCT %d", 0);
                geraCodigo (NULL, output);
            }
            | VERDADEIRO {
                // empilha constante para poder identificar tipagem
                node *aux = malloc(sizeof(node));
                char output[64];

                strcpy(aux->symbol, token);
                aux->type = BOOLEAN;
                aux->isFunction = 1;
                push(auxStack, aux);

                sprintf(output,"CRCT %d", 1);
                geraCodigo (NULL, output);
            }
;

expressao: expressao_associativa IGUAL expressao_comutativa {
                char output[64];
                comparativeExpression = 1;
                composedExpression = 1;
                if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                    sprintf(output, "cannot operate '=' with procedures\n");
                    imprimeErro(output);
                }
                sprintf(output,"CMIG");
                geraCodigo (NULL, output);
                hasBoolExpression = 1;
                 if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '=' with INTEGER values\n");
                    imprimeErro(output);
                }
                pop(auxStack);
            }
            | expressao_associativa DIFERENTE expressao_comutativa {
                char output[64];
                composedExpression = 1;
                comparativeExpression = 1;
                if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                    sprintf(output, "cannot operate '<>' with procedures\n");
                    imprimeErro(output);
                }
                sprintf(output,"CMDG");
                geraCodigo (NULL, output);
                hasBoolExpression = 1;
                if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '!=' with INTEGER values\n");
                    imprimeErro(output);
                }
                pop(auxStack);
            }
            | expressao_associativa MAIOR expressao_comutativa {
                char output[64];
                composedExpression = 1;
                comparativeExpression = 1;
                if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                    sprintf(output, "cannot operate '>' with procedures\n");
                    imprimeErro(output);
                }
                sprintf(output,"CMMA");
                geraCodigo (NULL, output);
                hasBoolExpression = 1;
                if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '>' with INTEGER values\n");
                    imprimeErro(output);
                }
                pop(auxStack);
            }
            | expressao_associativa MENOR expressao_comutativa {
                char output[64];
                composedExpression = 1;
                comparativeExpression = 1;
                if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                    sprintf(output, "cannot operate '<' with procedures\n");
                    imprimeErro(output);
                }
                sprintf(output,"CMME");
                geraCodigo (NULL, output);
                hasBoolExpression = 1;
                if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '<' with INTEGER values\n");
                    imprimeErro(output);
                }
                pop(auxStack);
            }
            | expressao_associativa MAIOR_IGUAL expressao_comutativa {
                char output[64];
                composedExpression = 1;
                comparativeExpression = 1;
                if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                    sprintf(output, "cannot operate '>=' with procedures\n");
                    imprimeErro(output);
                }
                sprintf(output,"CMAG");
                geraCodigo (NULL, output);
                hasBoolExpression = 1;
                if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '>=' with INTEGER values\n");
                    imprimeErro(output);
                }
                pop(auxStack);
            }
            | expressao_associativa MENOR_IGUAL expressao_comutativa {
                char output[64];
                composedExpression = 1;
                comparativeExpression = 1;
                if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                    sprintf(output, "cannot operate '<=' with procedures\n");
                    imprimeErro(output);
                }
                sprintf(output,"CMEG");
                geraCodigo (NULL, output);
                hasBoolExpression = 1;
                if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '<=' with INTEGER values\n");
                    imprimeErro(output);
                }
                pop(auxStack);
            }
            | expressao_associativa
            | expressao_comutativa
            | expressao_parenteses
            | constante {
                constantVal = 1;
            }
            | variavel
            | chamada_subrotina
;

expressao_associativa: expressao_associativa ADICAO expressao_comutativa {
                    char output[64];
                    composedExpression = 1;
                    if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                        sprintf(output, "cannot operate '+' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '+'\n");
                            imprimeErro(output);
                        }
                    }                                  
                    sprintf(output,"SOMA");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;
                    pop(auxStack);
                }
                | expressao_associativa SUBTRACAO expressao_comutativa {
                    char output[64];
                    composedExpression = 1;
                    
                    if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                        sprintf(output, "cannot operate '-' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '-'\n");
                            imprimeErro(output);
                        }
                    }
                    sprintf(output,"SUBT");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;
                    
                    pop(auxStack);
                }
                | expressao_comutativa OR expressao_parenteses {
                    char output[64];
                    composedExpression = 1;

                    if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                        sprintf(output, "cannot operate OR' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == INTEGER || auxStack->top->previous->type == INTEGER) {
                            if (!whileExpression && !ifExpression) {
                                sprintf(output, "INTEGER values are not allowed to operate 'or'\n");
                                imprimeErro(output);
                            }
                        }      
                    }             
                    sprintf(output,"DISJ");
                    geraCodigo (NULL, output);
                    hasBoolExpression = 1;                    
                    pop(auxStack);
                }
                | expressao_comutativa
;

expressao_comutativa: expressao_comutativa MULTIPLICACAO expressao_parenteses {
                    char output[64];
                    composedExpression = 1;
                    if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                        sprintf(output, "cannot operate '*' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '*'\n");
                            imprimeErro(output);
                        }         
                    }          
                    sprintf(output,"MULT");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;

                    pop(auxStack);
                }
                | expressao_comutativa DIVISAO_REAL expressao_parenteses {
                    char output[64];
                    composedExpression = 1;
                    if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                        sprintf(output, "cannot operate '/' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '/'\n");
                            imprimeErro(output);
                        }
                    }
                    sprintf(output,"DIVI");
                    geraCodigo (NULL, output);
                    pop(auxStack);
                }
                | expressao_comutativa DIVISAO expressao_parenteses {
                    char output[64];
                    composedExpression = 1;
                    if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                        sprintf(output, "cannot operate 'div' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate 'div'\n");
                            imprimeErro(output);
                        }
                    }
                    sprintf(output,"DIVI");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;                    
                    pop(auxStack);
                }
                | expressao_comutativa AND expressao_parenteses {
                    char output[64];
                    composedExpression = 1;
                    if (!auxStack->top->isFunction && !auxStack->top->previous->isFunction) {
                        sprintf(output, "cannot operate 'AND' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == INTEGER || auxStack->top->previous->type == INTEGER) {
                            if (!whileExpression && !ifExpression) {
                                sprintf(output, "INTEGER values are not allowed to operate 'and'\n");
                                imprimeErro(output);
                            }
                        }
                    }
                    sprintf(output,"CONJ");
                    geraCodigo (NULL, output);
                    hasBoolExpression = 1;
                    pop(auxStack);
                }
                | expressao_parenteses
                | constante {
                    constantVal = 1;
                }
                | variavel
                | chamada_subrotina
;

expressao_parenteses: ABRE_PARENTESES expressao FECHA_PARENTESES
                | constante {
                    constantVal = 1;
                }
                | variavel
                | chamada_subrotina
;

lista_idents: lista_idents VIRGULA IDENT
            | IDENT
;

while:  {
            assignDetected = 0;
            hasBoolExpression = 0;
            hasIntExpression = 0;
            whileExpression = 1;

            char output[64];
            char output2[64];

            if (labelNumber > 0) {
                labelNumber++;
            }

            sprintf(output2,"NADA");
            if (labelNumber < 10) {
                sprintf(output,"R0%d", labelNumber);
            }
            else {
                sprintf(output,"R%d", labelNumber);
            }
            geraCodigo (output, output2);

            labelNumber++;

            node *aux = malloc(sizeof(node));
            aux->label = labelNumber;
            push(labels, aux);
        }
        WHILE expressao DO {
            char output[64]; 
            hasBoolExpression = 0;
            hasIntExpression = 0;
            assignDetected = 0;

            if (!comparativeExpression) {
                sprintf(output, "invalid expression for WHILE statement");
                imprimeErro(output);
            }

            comparativeExpression = 0;

            node *aux = labels->top;

            if (aux->label < 10) {
                sprintf(output,"DSVF R0%d", labelNumber);
            }
            else {
                sprintf(output,"DSVF R%d", labelNumber);
            }
            geraCodigo (NULL, output);
            labelNumber++;
            whileExpression = 0;
        } comando_composto {            
            char output[64];
            node *aux = labels->top;

            if (aux->label - 1  < 10) {
                sprintf(output,"DSVS R0%d", aux->label - 1);
            }
            else {
                sprintf(output,"DSVS R%d", aux->label - 1);
            }
            geraCodigo (NULL, output);

            char output2[64];
            sprintf(output2,"NADA");
            if (aux->label < 10) {
                sprintf(output,"R0%d", aux->label);
            }
            else {
                sprintf(output,"R%d", aux->label);
            }
            geraCodigo (output, output2);

            pop(labels);
            labelNumber++;
        }

;

parametro_leitura: IDENT {
            int index = 0;
            char output[64];

            while (index <= tablePosition) {
                if (strcmp(symbolsTable[index].symbol, token) == 0 && symbolsTable[index].lex_level <= lex_level) {
                    break;
                }
                
                index++;
            }

            if (index > tablePosition) {
                sprintf(output, "symbol not declared '%s' identified\n", token);
                imprimeErro(output);
            }

            if (needRead) {
                sprintf(output,"LEIT");
                geraCodigo (NULL, output);

                sprintf(output,"ARMZ %d, %d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                geraCodigo (NULL, output);
            }
        }
        | NUMERO {
            char output[64];

            if (needRead) {
                sprintf(output, "Trying to read a constant value\n");
                imprimeErro(output);
            }
        }
;

parametros_escrita:  parametros_escrita VIRGULA expressao {
                char output[64];
                if (needWrite) {
                    sprintf(output,"IMPR");
                    geraCodigo (NULL, output);
                }
            }
            | expressao {
                char output[64];
                if (needWrite) {
                    sprintf(output,"IMPR");
                    geraCodigo (NULL, output);
                }
            }
;

parametros_leitura: parametros_leitura VIRGULA parametro_leitura
                    | parametro_leitura
;

outros_comandos: READ {
                    needRead = 1;
                } ABRE_PARENTESES 
                parametros_leitura FECHA_PARENTESES  {
                    needRead = 0;
                }
                | WRITE {
                    needWrite = 1;
                } ABRE_PARENTESES 
                parametros_escrita FECHA_PARENTESES {
                    needWrite = 0;
                }
;

then: THEN comando_ponto_e_virgula {
        char output[64];
        char output2[64];
        int aux1 = labels->top->label;

        pop(labels);
        node *aux = labels->top;
        
        if (aux->label < 10) {
            sprintf(output,"DSVS R0%d", aux->label);
        }
        else {
            sprintf(output,"DSVS R%d", aux->label);
        }
        geraCodigo (NULL, output);

        sprintf(output2,"NADA");
        if (aux1 < 10) {
            sprintf(output,"R0%d", aux1);
        }
        else {
            sprintf(output,"R%d", aux1);
        }
        geraCodigo (output, output2);   
    }
    | THEN comando_composto {
        char output[64];
        char output2[64];
        int aux1 = labels->top->label;

        pop(labels);
        node *aux = labels->top;
        
        if (aux->label < 10) {
            sprintf(output,"DSVS R0%d", aux->label);
        }
        else {
            sprintf(output,"DSVS R%d", aux->label);
        }
        geraCodigo (NULL, output);

        sprintf(output2,"NADA");
        if (aux1 < 10) {
            sprintf(output,"R0%d", aux1);
        }
        else {
            sprintf(output,"R%d", aux1);
        }
        geraCodigo (output, output2);   
    }
;

else: ELSE comando PONTO_E_VIRGULA
    {
        char output2[64];
        char output[64];        
        node *aux = labels->top;

        sprintf(output2, "NADA");
        if (aux->label < 10) {
            sprintf(output,"R0%d", aux->label);
        }
        else {
            sprintf(output,"R%d", aux->label);
        }
        geraCodigo (output, output2);

        pop(labels);
    }
    | ELSE comando
    {
        char output2[64];
        char output[64];        
        node *aux = labels->top;

        sprintf(output2, "NADA");
        if (aux->label < 10) {
            sprintf(output,"R0%d", aux->label);
        }
        else {
            sprintf(output,"R%d", aux->label);
        }
        geraCodigo (output, output2);

        pop(labels);
    }
    | ELSE comando_composto {
        char output2[64];
        char output[64];        
        node *aux = labels->top;

        sprintf(output2, "NADA");
        if (aux->label < 10) {
            sprintf(output,"R0%d", aux->label);
        }
        else {
            sprintf(output,"R%d", aux->label);
        }
        geraCodigo (output, output2);

        pop(labels);
    }
    | %prec LOWER_THAN_ELSE {
        char output2[64];
        char output[64];        
        node *aux = labels->top;

        sprintf(output2, "NADA");
        if (aux->label < 10) {
            sprintf(output,"R0%d", aux->label);
        }
        else {
            sprintf(output,"R%d", aux->label);
        }
        geraCodigo (output, output2);

        pop(labels);
    }
;

if: IF {
            ifExpression = 1;
        } expressao {
        char output[64];

        if (!comparativeExpression) {
            sprintf(output, "invalid expression for IF statement");
            imprimeErro(output);
        }
        hasBoolExpression = 0;
        hasIntExpression = 0;
        assignDetected = 0;
        comparativeExpression = 0;

        node *aux = malloc(sizeof(node));
        

        aux->label = labelNumber;
        push(labels, aux);

        labelNumber++;
        
        if (labelNumber < 10) {
            sprintf(output,"DSVF R0%d", labelNumber);
        }
        else {
            sprintf(output,"DSVF R%d", labelNumber);
        }
        geraCodigo (NULL, output);    

        aux = malloc(sizeof(node));
        aux->label = labelNumber;
        push(labels, aux);

        labelNumber++;
        ifExpression = 0; 
    } then else
;

lista_id_parametro: lista_id_parametro VIRGULA IDENT {
                        char output[64];

                        if (shouldCheckParams) {
                            for (int i = tablePosition; i >= 0; i--) {                                 
                                if ((strcmp(procedureTokenCheck, symbolsTable[i].symbol)) == 0 && (symbolsTable[i].def == IS_FUNCTION || symbolsTable[i].def == IS_PROCEDURE) && symbolsTable[i].hasFoward) {
                                    sprintf(output, "symbol '%s' does not match forward param", token);
                                    imprimeErro(output);
                                }

                                if (strcmp(token, symbolsTable[i].symbol) == 0) {
                                    if (symbolsTable[i].parameter_foward && symbolsTable[i].paramIndex != paramIndex && symbolsTable[i].lex_level == lex_level) {
                                        sprintf(output, "symbol '%s' does not match forward param", token);
                                        imprimeErro(output);
                                    }
                                    else if (symbolsTable[i].parameter_foward && symbolsTable[i].lex_level == lex_level) {
                                        break;
                                    }
                                }
                            }
                        }

                        // Checa se símbolo já está declarado na tabela de símbolos
                        for (int i = tablePosition; i >= 0; i--) {
                            if (strcmp(token, symbolsTable[i].symbol) == 0 && symbolsTable[i].lex_level == lex_level && !symbolsTable[i].parameter_foward) {
                                sprintf(output, "symbol '%s' already declared as a parameter", token);
                                imprimeErro(output);
                            }

                            if (strcmp(token, symbolsTable[i].symbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && symbolsTable[i].lex_level <= lex_level) {
                                sprintf(output, "symbol '%s'  already declared as a procedure", token);
                                imprimeErro(output);
                            }
                        }
                        tablePosition++;
                        strcpy(symbolsTable[tablePosition].symbol, token);
                        symbolsTable[tablePosition].lex_level = lex_level;
                        symbolsTable[tablePosition].def = FORMAL_PARAM;
                        symbolsTable[tablePosition].paramIndex = paramIndex;
                        
                        if (passedByReference) {
                            symbolsTable[tablePosition].by_reference = BY_REFERENCE;  
                        }
                        else {
                            symbolsTable[tablePosition].by_reference = BY_VALUE;
                        }

                        paramIndex++;
                    }
                    | IDENT {
                        char output[64];

                        if (shouldCheckParams) {
                            for (int i = tablePosition; i >= 0; i--) {                                 
                                if ((strcmp(procedureTokenCheck, symbolsTable[i].symbol)) == 0 && (symbolsTable[i].def == IS_FUNCTION || symbolsTable[i].def == IS_PROCEDURE) && symbolsTable[i].hasFoward) {
                                    sprintf(output, "symbol '%s' does not match forward param", token);
                                    imprimeErro(output);
                                }

                                if (strcmp(token, symbolsTable[i].symbol) == 0) {
                                    if (symbolsTable[i].parameter_foward && symbolsTable[i].paramIndex != paramIndex && symbolsTable[i].lex_level == lex_level) {
                                        sprintf(output, "symbol '%s' does not match forward param", token);
                                        imprimeErro(output);
                                    }
                                    else if (symbolsTable[i].parameter_foward && symbolsTable[i].lex_level == lex_level) {
                                        break;
                                    }
                                }
                            }
                        }

                        // Checa se símbolo já está declarado na tabela de símbolos
                        for (int i = tablePosition; i >= 0; i--) {
                            if (strcmp(token, symbolsTable[i].symbol) == 0 && symbolsTable[i].lex_level == lex_level && !symbolsTable[i].parameter_foward) {
                                sprintf(output, "symbol '%s'  already declared as a parameter", token);
                                imprimeErro(output);
                            }

                            if (strcmp(token, symbolsTable[i].symbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && symbolsTable[i].lex_level <= lex_level) {
                                sprintf(output, "symbol '%s'  already declared as a procedure", token);
                                imprimeErro(output);
                            }
                        }
                        tablePosition++;
                        strcpy(symbolsTable[tablePosition].symbol, token);
                        symbolsTable[tablePosition].lex_level = lex_level;
                        symbolsTable[tablePosition].def = FORMAL_PARAM;

                        if (passedByReference) {
                            symbolsTable[tablePosition].by_reference = BY_REFERENCE;  
                        }
                        else {
                            symbolsTable[tablePosition].by_reference = BY_VALUE;
                        }

                        paramIndex++;
                    }
;

parametro_procedimento: { 
                            passedByReference = 0;
                    } lista_id_parametro DOIS_PONTOS IDENT {
                        for (int i = tablePosition; i >= 0; i--) {                                
                            if (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) {
                                break;
                            }

                            if (strcmp(token, "integer") == 0) {
                                symbolsTable[i].type = INTEGER;
                            }
                            else if (strcmp(token, "boolean") == 0) {
                                symbolsTable[i].type = BOOLEAN;
                            }
                            else {
                                char output[64];
                                sprintf(output, "unidentified type '%s'", token);
                                imprimeErro(output);
                            }
                        }
                    }
                    | VAR { 
                        passedByReference = 1; 
                    }
                    lista_id_parametro DOIS_PONTOS IDENT {
                        for (int i = tablePosition; i >= 0; i--) {                                
                            if (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) {
                                break;
                            }

                            if (strcmp(token, "integer") == 0) {
                                symbolsTable[i].type = INTEGER;
                            }
                            else if (strcmp(token, "boolean") == 0) {
                                symbolsTable[i].type = BOOLEAN;
                            }
                            else {
                                char output[64];
                                sprintf(output, "unidentified type '%s'", token);
                                imprimeErro(output);
                            }
                        }
                    }
;

parametros_procedimento: parametros_procedimento PONTO_E_VIRGULA parametro_procedimento 
                        | parametro_procedimento
                        |
;

parametros_formais: ABRE_PARENTESES parametros_procedimento FECHA_PARENTESES {
                        int procedureParamsOffset = -4;
                        int countParams = 0;
                        int procedureIndex = -1;
                        char output[64];

                        int found = 0;

                        if (shouldCheckParams) {
                            for (int i = tablePosition; i >= 0; i--) {                                    
                                if ((strcmp(procedureTokenCheck, symbolsTable[i].symbol)) == 0 && (symbolsTable[i].def == IS_FUNCTION || symbolsTable[i].def == IS_PROCEDURE) && symbolsTable[i].hasFoward) {
                                   break;
                                }

                                for (int j = i - 1; j >= 0; j--) {
                                    if (strcmp(symbolsTable[i].symbol, symbolsTable[j].symbol) == 0) {
                                        //printf("\n\n\n\n %s %d %d\n\n\n\n", symbolsTable[j].symbol, symbolsTable[i].type, symbolsTable[j].type);
                                        if (symbolsTable[j].parameter_foward &&  symbolsTable[i].type != symbolsTable[j].type) {
                                            sprintf(output, "symbol '%s' does doest not match the type declared in the forward statement", symbolsTable[i].symbol);
                                            imprimeErro(output);
                                        }
                                        else {
                                            found = 1;
                                            break;
                                        }
                                    }
                                }

                                if (found) {
                                    break;
                                }
                            }
                        }

                        if (paramIndex != totalParams + 1 && shouldCheckParams) {
                            sprintf(output, "number of params does not match the forward function");
                            imprimeErro(output);
                        }
                        else {

                        }
                        paramIndex = 0;
                        totalParams = 0;

                        for (int i = tablePosition; i >= 0; i--) {
                            if (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) {
                                procedureIndex = i;
                                break;
                            }
                        }

                        for (int i = tablePosition; i >= 0; i--) {
                            if (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) {
                                break;
                            }

                            if (symbolsTable[i].def == FORMAL_PARAM) {
                                symbolsTable[i].offset = procedureParamsOffset;
                                procedureParamsOffset--;

                                // atualiza contagem de parametros no procedimento e o tipo do parametro até então
                                symbolsTable[procedureIndex].total_params++;

                                if (symbolsTable[i].type == INTEGER) {
                                    symbolsTable[procedureIndex].params[countParams].type = INTEGER;
                                }
                                else if (symbolsTable[i].type == BOOLEAN) {
                                    symbolsTable[procedureIndex].params[countParams].type = BOOLEAN;
                                }

                                symbolsTable[procedureIndex].params[countParams].by_reference = symbolsTable[i].by_reference;
                               
                                countParams++;
                            }
                        }

                        if (symbolsTable[procedureIndex].def == IS_FUNCTION) {
                            symbolsTable[procedureIndex].offset = procedureParamsOffset;
                        }
                    }
                    | {
                        for (int i = tablePosition; i >= 0; i--) {
                            if (symbolsTable[i].def == IS_FUNCTION) {
                                symbolsTable[i].offset = -4;
                            }
                            break;
                        }
                    }
;  

procedure_fim: bloco {
            char output[64];
            char output2[64];
            int count = 0;
            int index = 0;

            for (int i = tablePosition; i >= 0; i--) {
                if (symbolsTable[i].def == IS_PROCEDURE) {
                    index = i;
                    break;
                }
            }

            sprintf(output, "RTPR %d, %d", lex_level, symbolsTable[index].total_params + 1);
            geraCodigo (NULL, output);

            labelNumber++;

            haveProcedures = 1;
            countProcedures--;

            lex_level--;

            sprintf(output2, "NADA");
            if (countElements(procedureLabels) > 0) {
                node *aux = procedureLabels->top;
            
                if (aux->label > 10) {
                    sprintf(output, "R%d", aux->label);
                }
                else {
                    sprintf(output, "R0%d", aux->label);
                }
                geraCodigo (output, output2);
                pop(procedureLabels);
            }

            labelNumber++;

            for (int i = tablePosition; i >= 0; i--) {
                if (symbolsTable[i].def == IS_PROCEDURE) {
                    if (symbolsTable[i].lex_level > lex_level + 1) {
                        count++;
                    }
                }

                if ((symbolsTable[i].def == SIMPLE_VARIABLE || symbolsTable[i].def == FORMAL_PARAM) && symbolsTable[i].lex_level > lex_level) {
                    count++;
                }
            }

            tablePosition -= count;
        }
        | FORWARD {
            char output[64]; 
            char output2[64]; 

            lex_level--;
            
            symbolsTable[lastProcedureTableIndex].hasFoward = 1; 
            symbolsTable[lastProcedureTableIndex].fowardedLabel = labelNumber;

            if (labelNumber < 10) {
                sprintf(output, "DSVS R0%d", labelNumber);
            }
            else {
                sprintf(output, "DSVS R%d", labelNumber);
            }
            geraCodigo (NULL, output);

            sprintf(output2, "NADA");
            if (countElements(procedureLabels) > 0) {
                node *aux = procedureLabels->top;
            
                if (aux->label > 10) {
                    sprintf(output, "R%d", aux->label);
                }
                else {
                    sprintf(output, "R0%d", aux->label);
                }
                geraCodigo (output, output2);
                pop(procedureLabels);
            }
            labelNumber++;

            countProcedures--;

            for (int i = tablePosition; i >= 0; i++) {
                if (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) {
                    break;
                }

                symbolsTable[i].parameter_foward = 1;
            }

        } PONTO_E_VIRGULA
;

procedure: PROCEDURE IDENT {
            char output[64];  
            char output2[64];

            int redirectedByForward = 0;
            int tableIndexForward;
                
            // Checa se símbolo já está declarado na tabela de símbolos
            for (int i = tablePosition; i >= 0; i--) {
                if (strcmp(token, symbolsTable[i].symbol) == 0 && symbolsTable[i].lex_level <= lex_level) {
                    // Caso tenha detectado o forward
                    if (symbolsTable[i].hasFoward){
                        redirectedByForward = 1;
                        tableIndexForward = i;

                    } else {
                        sprintf(output, "symbol '%s'  already declared", token);
                        imprimeErro(output);
                    }
                }

                if (strcmp(token, symbolsTable[i].symbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && symbolsTable[i].lex_level == lex_level + 1) {
                    if (symbolsTable[i].hasFoward){
                        tableIndexForward = i;
                        redirectedByForward = 1;
                    } else {
                        sprintf(output, "symbol '%s'  already declared as a procedure", token);
                        imprimeErro(output);
                    }
                }
            }

            /* Salva token do procedimento na tabela de símbolos */
            tablePosition++;
            lex_level++;
            strcpy(symbolsTable[tablePosition].symbol, token);
            symbolsTable[tablePosition].lex_level = lex_level;
            symbolsTable[tablePosition].offset = offset;
            symbolsTable[tablePosition].def = IS_PROCEDURE;
            symbolsTable[tablePosition].total_params = -1; 
            symbolsTable[tablePosition].hasFoward = 0; 
            symbolsTable[tablePosition].fowarded = 0;
            
            offset = 0;
            num_vars = 0;            
            /* --------------------------------------------- */

            lastProcedureTableIndex = tablePosition;

            countProcedures++;

             if (!redirectedByForward) {
                node *aux = malloc(sizeof(node));                
                    
                aux->label = labelNumber;
                push(procedureLabels, aux);
                        
                if (labelNumber < 10) {
                    sprintf(output, "DSVS R0%d", labelNumber);
                }
                else {
                    sprintf(output, "DSVS R%d", labelNumber);
                }
                geraCodigo (NULL, output);
                labelNumber++;

                sprintf(output2, "ENPR %d", lex_level);
                if (labelNumber < 10) {
                    sprintf(output, "R0%d", labelNumber);
                }
                else {
                    sprintf(output, "R%d", labelNumber);
                }
            
                symbolsTable[tablePosition].label = labelNumber;

                geraCodigo (output, output2);

            }
            else {
                node *aux = malloc(sizeof(node));                
                    
                aux->label = labelNumber;
                push(procedureLabels, aux);
                        
                if (labelNumber < 10) {
                    sprintf(output, "DSVS R0%d", labelNumber);
                }
                else {
                    sprintf(output, "DSVS R%d", labelNumber);
                }
                geraCodigo (NULL, output);
                labelNumber++;

                symbolsTable[tablePosition].fowarded = 1;
                symbolsTable[tablePosition].fowardedLabel = symbolsTable[tableIndexForward].label;
       
                sprintf(output2, "NADA");
                if (symbolsTable[tableIndexForward].fowardedLabel < 10) {
                    sprintf(output, "R0%d", symbolsTable[tableIndexForward].fowardedLabel);
                }
                else {
                    sprintf(output, "R%d", symbolsTable[tableIndexForward].fowardedLabel);
                }
                geraCodigo (output, output2);

                shouldCheckParams = 1;
                totalParams = symbolsTable[tableIndexForward].total_params;
                strcpy(procedureTokenCheck, symbolsTable[tableIndexForward].symbol);
                paramIndex = 0;
            }
            labelNumber++;



        } parametros_formais PONTO_E_VIRGULA procedure_fim
;

subrotina: procedure
            | funcao
;

subrotinas: subrotinas subrotina PONTO_E_VIRGULA
            | subrotinas PONTO_E_VIRGULA subrotina
            | subrotinas subrotina 
            | subrotina PONTO_E_VIRGULA
            | subrotina
            |
;

parametros_chamada_subrotina: parametros_chamada_subrotina VIRGULA expressao {
                                char  output[64];
                                node *aux = auxStack->top;

                                for (int i = tablePosition; i >= 0; i--) {
                                    if (strcmp(symbolsTable[i].symbol, lastProcSymbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && 
                                        (symbolsTable[i].lex_level <= lex_level || symbolsTable[i].lex_level == lex_level + 1)) {
                                        
                                        if (symbolsTable[i].params[symbolsTable[i].total_params - countProcedureParams].by_reference == BY_REFERENCE) {
                                            if (composedExpression) {
                                                sprintf(output, "parameters passed by reference cannot be expressions\n");
                                                imprimeErro(output);
                                            }

                                            if (constantVal) {
                                                sprintf(output, "parameters passed by reference cannot be constant values\n");
                                                imprimeErro(output);
                                            }
                                            
                                            for (int j = tablePosition; j >= 0; j--) {
                                                if (strcmp(aux->symbol, symbolsTable[j].symbol) == 0 && 
                                                    (symbolsTable[j].lex_level <= lex_level || symbolsTable[j].lex_level == lex_level + 1)) {
                                                        if (symbolsTable[j].by_reference != BY_REFERENCE) {
                                                            sprintf(output,"CREN %d, %d",symbolsTable[j].lex_level, symbolsTable[j].offset);
                                                            geraCodigo (NULL, output);
                                                            break;
                                                        }
                                                        else {
                                                            sprintf(output,"CRVL %d, %d",symbolsTable[j].lex_level, symbolsTable[j].offset);
                                                            geraCodigo (NULL, output);
                                                            break;
                                                        }
                                                    }
                                            }
                                        }
                                        
                                    }
                                }

                                countProcedureParams++;
                                composedExpression = 0; 
                                constantVal = 0;  
                                pop(auxStack);                             
                            }
                            | expressao {
                                char  output[64]; 
                                node *aux = auxStack->top;

                                for (int i = tablePosition; i >= 0; i--) {
                                    if (strcmp(symbolsTable[i].symbol, lastProcSymbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && 
                                        (symbolsTable[i].lex_level <= lex_level || symbolsTable[i].lex_level == lex_level + 1)) {
                                        
                                        if (symbolsTable[i].params[symbolsTable[i].total_params - countProcedureParams].by_reference == BY_REFERENCE) {
                                            if (composedExpression) {
                                                sprintf(output, "parameters passed by reference cannot be expressions\n");
                                                imprimeErro(output);
                                            }

                                            if (constantVal) {
                                                sprintf(output, "parameters passed by reference cannot be constant values\n");
                                                imprimeErro(output);
                                            }

                                            for (int j = tablePosition; j >= 0; j--) {
                                                if (strcmp(aux->symbol, symbolsTable[j].symbol) == 0 && 
                                                    (symbolsTable[j].lex_level <= lex_level || symbolsTable[j].lex_level == lex_level + 1)) {
                                                        if (symbolsTable[j].by_reference != BY_REFERENCE) {
                                                            sprintf(output,"CREN %d, %d",symbolsTable[j].lex_level, symbolsTable[j].offset);
                                                            geraCodigo (NULL, output);
                                                            break;
                                                        }
                                                        else {
                                                            sprintf(output,"CRVL %d, %d",symbolsTable[j].lex_level, symbolsTable[j].offset);
                                                            geraCodigo (NULL, output);
                                                            break;
                                                        }
                                                    }
                                            }
                                
                                        }
                                    }
                                }

                                countProcedureParams++;
                                composedExpression = 0;
                                constantVal = 0;
                                pop(auxStack);
                            }
                            |
;

chamada_subrotina: variavel ABRE_PARENTESES {
                        if (procedureCall) {
                            procedureWithParams = 1;
                        }
                    } parametros_chamada_subrotina 
                    FECHA_PARENTESES {            
                        if (procedureWithParams) {
                            char  output[64];

                            for (int i = tablePosition; i >= 0; i--) {
                                if (strcmp(symbolsTable[i].symbol, lastProcSymbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && 
                                    (symbolsTable[i].lex_level <= lex_level || symbolsTable[i].lex_level == lex_level + 1)) {
                                    
                                    // Se número de parametros for diferente do esperado, retorna erro
                                    if (symbolsTable[i].total_params + 1 != countProcedureParams) {
                                        sprintf(output, "number of params to procedure '%s' does not match, expected %d, found %d\n", symbolsTable[i].symbol, symbolsTable[i].total_params + 1, countProcedureParams);                                        
                                        imprimeErro(output);
                                    }
                                    
                                    int label = symbolsTable[i].label;
                                    if (symbolsTable[i].fowarded) {
                                        label = symbolsTable[i].fowardedLabel;
                                    }

                                    if (label  < 10) {
                                        sprintf(output,"CHPR R0%d, %d", label, lex_level);
                                    }
                                    else {
                                        sprintf(output,"CHPR R%d, %d", label, lex_level);
                                    }
                                    geraCodigo (NULL, output);
                                    break;
                                }
                            }

                            lastProcSymbol[0] = '\0';  
                        }

                        procedureWithParams = 0;
                        countProcedureParams = 0;
                }
                | variavel {
                    if (procedureCall) {
                        char  output[64];
                        for (int i = tablePosition; i >= 0; i--) {
                            if (strcmp(symbolsTable[i].symbol, lastProcSymbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && 
                                    (symbolsTable[i].lex_level <= lex_level || symbolsTable[i].lex_level == lex_level + 1)) {
                                
                                // Se número de parametros for diferente do esperado, retorna erro
                                if (symbolsTable[i].total_params + 1 != countProcedureParams) {
                                    sprintf(output, "number of params to procedure '%s' does not match, expected %d, found %d\n", symbolsTable[i].symbol, symbolsTable[i].total_params + 1, countProcedureParams);
                                    imprimeErro(output);
                                }

                                int label = symbolsTable[i].label;
                                if (symbolsTable[i].fowarded) {
                                    label = symbolsTable[i].fowardedLabel;
                                }

                                if (symbolsTable[i].label  < 10) {
                                    sprintf(output,"CHPR R0%d, %d", label, lex_level);
                                }
                                else {
                                    sprintf(output,"CHPR R%d, %d", label, lex_level);
                                }
                                geraCodigo (NULL, output);
                                break;
                            }
                        }
                    }
                    procedureCall = 0;
                    countProcedureParams = 0;
                }
;

funcao_fim: bloco {
            char output[64];
            char output2[64];
            int count = 0;
            int index = 0;

            for (int i = tablePosition; i >= 0; i--) {
                if (symbolsTable[i].def == IS_FUNCTION) {
                    index = i;
                    break;
                }
            }

            sprintf(output, "RTPR %d, %d", lex_level, symbolsTable[index].total_params + 1);
            geraCodigo (NULL, output);

            labelNumber++;

            haveProcedures = 1;
            countProcedures--;

            lex_level--;

            sprintf(output2, "NADA");
            if (countElements(procedureLabels) > 0) {
                node *aux = procedureLabels->top;
            
                if (aux->label > 10) {
                    sprintf(output, "R%d", aux->label);
                }
                else {
                    sprintf(output, "R0%d", aux->label);
                }
                geraCodigo (output, output2);
                pop(procedureLabels);
            }

            labelNumber++;

            for (int i = tablePosition; i >= 0; i--) {
                if (symbolsTable[i].def == IS_FUNCTION) {
                    break;
                }

                if (symbolsTable[i].def == IS_FUNCTION) {
                    if (symbolsTable[i].lex_level > lex_level + 1) {
                        count++;
                    }
                }

                if ((symbolsTable[i].def == SIMPLE_VARIABLE || symbolsTable[i].def == FORMAL_PARAM) && symbolsTable[i].lex_level > lex_level) {
                    count++;
                }
            }

            tablePosition -= count;
        }
        | FORWARD {
            char output[64]; 
            char output2[64]; 

            lex_level--;
            
            symbolsTable[lastProcedureTableIndex].hasFoward = 1; 
            symbolsTable[lastProcedureTableIndex].fowardedLabel = labelNumber;

            if (labelNumber < 10) {
                sprintf(output, "DSVS R0%d", labelNumber);
            }
            else {
                sprintf(output, "DSVS R%d", labelNumber);
            }
            geraCodigo (NULL, output);

            sprintf(output2, "NADA");
            if (countElements(procedureLabels) > 0) {
                node *aux = procedureLabels->top;
            
                if (aux->label > 10) {
                    sprintf(output, "R%d", aux->label);
                }
                else {
                    sprintf(output, "R0%d", aux->label);
                }
                geraCodigo (output, output2);
                pop(procedureLabels);
            }
            labelNumber++;

            countProcedures--;
            
            for (int i = tablePosition; i >= 0; i--) {
                if (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) {
                    break;
                }

                symbolsTable[i].parameter_foward = 1;
            }
        }
;

funcao: FUNCTION IDENT {
            char output[64];  
            char output2[64];

            int redirectedByForward = 0;
            int tableIndexForward;

            // Checa se símbolo já está declarado na tabela de símbolos
            for (int i = tablePosition; i >= 0; i--) {
                if (strcmp(token, symbolsTable[i].symbol) == 0 && symbolsTable[i].lex_level <= lex_level) {
                    if (symbolsTable[i].hasFoward){
                        redirectedByForward = 1;
                        tableIndexForward = i;

                    } else {
                        sprintf(output, "symbol '%s'  already declared", token);
                        imprimeErro(output);
                    }
                }

                if (strcmp(token, symbolsTable[i].symbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && symbolsTable[i].lex_level == lex_level + 1) {
                    if (symbolsTable[i].hasFoward){
                        redirectedByForward = 1;
                        tableIndexForward = i;

                    } else {
                        sprintf(output, "symbol '%s' already declared as a procedure or function", token);
                        imprimeErro(output);
                    }
                }
            }

            /* Salva token do procedimento na tabela de símbolos */
            tablePosition++;
            lex_level++;
            strcpy(symbolsTable[tablePosition].symbol, token);
            symbolsTable[tablePosition].lex_level = lex_level;
            symbolsTable[tablePosition].offset = offset;
            symbolsTable[tablePosition].def = IS_FUNCTION;
            symbolsTable[tablePosition].total_params = -1;
            symbolsTable[tablePosition].hasFoward = 0; 
            symbolsTable[tablePosition].fowarded = 0;

            offset = 0;
            num_vars = 0;

            lastProcedureTableIndex = tablePosition;
            
            /* --------------------------------------------- */

            node *aux = malloc(sizeof(node));

            countProcedures++;
            

            if (!redirectedByForward) {
                aux->label = labelNumber;
                push(procedureLabels, aux);
                        
                if (labelNumber < 10) {
                    sprintf(output, "DSVS R0%d", labelNumber);
                }
                else {
                    sprintf(output, "DSVS R%d", labelNumber);
                }
                geraCodigo (NULL, output);
                labelNumber++;
                
                sprintf(output2, "ENPR %d", lex_level);
                if (labelNumber < 10) {
                    sprintf(output, "R0%d", labelNumber);
                }
                else {
                    sprintf(output, "R%d", labelNumber);
                }
                symbolsTable[tablePosition].label = labelNumber;
                geraCodigo (output, output2);
            }
            else {
                node *aux = malloc(sizeof(node));                
                    
                aux->label = labelNumber;
                push(procedureLabels, aux);
                        
                if (labelNumber < 10) {
                    sprintf(output, "DSVS R0%d", labelNumber);
                }
                else {
                    sprintf(output, "DSVS R%d", labelNumber);
                }
                geraCodigo (NULL, output);
                labelNumber++;

                symbolsTable[tablePosition].fowarded = 1;
                symbolsTable[tablePosition].fowardedLabel = symbolsTable[tableIndexForward].label;


                sprintf(output2, "NADA");
                if (symbolsTable[tableIndexForward].fowardedLabel < 10) {
                    sprintf(output, "R0%d", symbolsTable[tableIndexForward].fowardedLabel);
                }
                else {
                    sprintf(output, "R%d", symbolsTable[tableIndexForward].fowardedLabel);
                }
                geraCodigo (output, output2);

                shouldCheckParams = 1;
                totalParams = symbolsTable[tableIndexForward].total_params;
                strcpy(procedureTokenCheck, symbolsTable[tableIndexForward].symbol);
                paramIndex = 0;
            }

            labelNumber++;
        } parametros_formais DOIS_PONTOS IDENT {
            // Identifica tipo da função
            for (int i = tablePosition; i >= 0; i--) {
                if (symbolsTable[i].def == IS_FUNCTION) {
                    if (strcmp(token, "integer") == 0) {
                        symbolsTable[i].type = INTEGER;
                    }
                    else if (strcmp(token, "boolean") == 0) {
                        symbolsTable[i].type = BOOLEAN;
                    }
                    else {
                        char output[64];
                        sprintf(output, "unidentified type '%s'", token);
                        imprimeErro(output);
                    }
                    break;
                }
            }
        } PONTO_E_VIRGULA funcao_fim
;

comando_composto: T_BEGIN  comandos T_END
;

comandos: comandos comando PONTO_E_VIRGULA
        | comandos PONTO_E_VIRGULA comando 
        | comandos comando 
        | comando PONTO_E_VIRGULA
        | comando
;

comando_ponto_e_virgula: comando PONTO_E_VIRGULA
                        | comando
;

comando: {
            assignDetected = 1;
        } atribuicao
        | while
        | if
        | outros_comandos
        |
;

%%

int main (int argc, char** argv) {
   FILE* fp;
   extern FILE* yyin;

   if (argc<2 || argc>2) {
         printf("usage compilador <arq>a %d\n", argc);
         return(-1);
      }

   fp=fopen (argv[1], "r");
   if (fp == NULL) {
      printf("usage compilador <arq>b\n");
      return(-1);
   }


    /* -------------------------------------------------------------------
    *  Inicia a Tabela de S�mbolos
    * ------------------------------------------------------------------- */
    auxStack = declareStack();
    assignVariables = declareStack();
    labels = declareStack();
    procedureLabels = declareStack();
    lastProcSymbol[0] = '\0';

   yyin=fp;
   yyparse();

   return 0;
}
