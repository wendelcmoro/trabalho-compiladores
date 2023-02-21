
// Testar se funciona corretamente o empilhamento de par�metros
// passados por valor ou por refer�ncia.


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
char last_command[MAX_SYMBOL_SIZE];

// symbols table represented as an array
Symbol symbolsTable[255];
int tablePosition = -1;

stack *auxStack;
stack *varTypeStack;
stack *assignVariables;
//stack *identTypes;
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

/* Variáveis usadas para auxiliar nos procedimentos */
int haveProcedures = 0;
int countProcedures = 0;
int procedureCall = 0;
int procedureWithParams = 0;
char lastProcSymbol[64];
int countProcedureParams = 0;
int composedExpression = 0;
int needLoadVal = 0;
int constantVal = 0;

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
%token IF THEN ELSE

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

bloco       : parte_declara_vars procedures
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
                int index = 0;

                if (assignVariables->top->type != auxStack->top->type) {
                    sprintf(output, "trying to assign value of different type to variable '%s'\n", assignVariables->top->symbol);
                    imprimeErro(output);
                }

                while(strcmp(symbolsTable[index].symbol, last_ident.token) != 0) {
                    if (index > tablePosition) {
                        break;
                    }     
                    index++;               
                }

                if (index <= tablePosition) {
                    if (symbolsTable[index].by_reference) {
                        sprintf(output,"ARMI %d,%d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    }
                    else {
                        sprintf(output,"ARMZ %d,%d", symbolsTable[index].lex_level, symbolsTable[index].offset);
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
                int index = 0;
                char output[64];

                if (procedureCall) {
                    sprintf(output, "trying to assign procedure to variable '%s'\n", aux->symbol);
                    imprimeErro(output);
                }

                if (assignVariables->top->type != aux->type) {
                    sprintf(output, "trying to assign value of different type to variable '%s'\n", assignVariables->top->symbol);
                    imprimeErro(output);
                }
                aux = aux->previous;
                while (index <= tablePosition) {
                    if (strcmp(symbolsTable[index].symbol, aux->symbol) == 0 && symbolsTable[index].lex_level <= lex_level) {
                        break;
                    }

                    index++;
                }

                if (index <= tablePosition) {
                    if (symbolsTable[index].by_reference) {
                        sprintf(output,"ARMI %d,%d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    }
                    else {
                        sprintf(output,"ARMZ %d,%d", symbolsTable[index].lex_level, symbolsTable[index].offset);
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
                int index = 0;

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
                
                while(strcmp(symbolsTable[index].symbol, assignVariables->top->symbol) != 0 && symbolsTable[index].lex_level <= lex_level && index <= tablePosition) {   
                    index++;
                }
                if (index <= tablePosition) {
                    if (symbolsTable[index].by_reference) {
                        sprintf(output,"ARMI %d,%d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    }
                    else {
                        sprintf(output,"ARMZ %d,%d", symbolsTable[index].lex_level, symbolsTable[index].offset);
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
            // printf("\n\n\n\n %d %s %d \n\n\n\n", index, token, lex_level);
            // printf("\n\n\n\n %s \n\n\n\n", symbolsTable[index - 1].symbol);
            char output[64];

            node *aux = malloc(sizeof(node));
            strcpy(aux->symbol, token);

            // busca o símbolo na tabela de símbolos para poder identificação
            //index = tablePosition;       
            while (index >= 0) {
                if ((strcmp(symbolsTable[index].symbol, token) == 0 && symbolsTable[index].lex_level <= lex_level && symbolsTable[index].def != IS_PROCEDURE && symbolsTable[index].def != IS_FUNCTION) 
                    || (strcmp(symbolsTable[index].symbol, token) == 0 && (symbolsTable[index].def == IS_PROCEDURE || symbolsTable[index].def == IS_FUNCTION) && symbolsTable[index].lex_level >= symbolsTable[index].lex_level)) {
                    break;
                }
                
                //printf ("\n\n\n\n%d\n\n\n\n", index);
                index--;
            }

            //printf ("\n\n\n\n aqui %d\n\n\n\n", symbolsTable[index].offset);

            if (index >= 0) {                
                if (symbolsTable[index].def == IS_PROCEDURE || symbolsTable[index].def == IS_FUNCTION) {
                    procedureCall = 1;
                }
                else {
                    procedureCall = 0;
                    aux->type = symbolsTable[index].type;
                }
            }
            else {
                sprintf(output, "symbol not declared '%s' identified\n", aux->symbol);
                imprimeErro(output);
            }

            if ((!procedureCall) || symbolsTable[index].def == IS_FUNCTION) {
                push(auxStack, aux);
                strcpy(last_ident.token, token);
            }
            else {
                free(aux);
            }

            if (!assignDetected && symbolsTable[index].def == IS_FUNCTION) {
                sprintf(output,"AMEM 1");
                geraCodigo (NULL, output);
            }

            if (assignDetected && (!procedureCall || symbolsTable[index].def == IS_FUNCTION)) {
                node *aux2 = malloc(sizeof(node));
                aux2->type = auxStack->top->type;
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
                        sprintf(output,"CRVL %d,%d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                    } else{
                        sprintf(output,"CRVI %d,%d", symbolsTable[index].lex_level, symbolsTable[index].offset);
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
                                                sprintf(output,"CRVL %d,%d", symbolsTable[index].lex_level, symbolsTable[index].offset);
                                                geraCodigo (NULL, output);
                                                found = 1;
                                                break;
                                            }
                                            else if (symbolsTable[j].by_reference == BY_REFERENCE) {
                                                sprintf(output,"CRVI %d,%d", symbolsTable[index].lex_level, symbolsTable[index].offset);
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
                push(auxStack, aux);

                sprintf(output,"CRCT %d", 1);
                geraCodigo (NULL, output);
            }
;

expressao: expressao_associativa IGUAL expressao_comutativa {
                char output[64];
                composedExpression = 1;
                if (procedureCall) {
                    sprintf(output, "cannot operate '=' with procedures\n");
                    imprimeErro(output);
                }
                sprintf(output,"CMIG");
                geraCodigo (NULL, output);
                 if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '=' with INTEGER values\n");
                    imprimeErro(output);
                }
                //pop(auxStack);
                pop(auxStack);
            }
            | expressao_associativa DIFERENTE expressao_comutativa {
                char output[64];
                composedExpression = 1;
                if (procedureCall) {
                    sprintf(output, "cannot operate '<>' with procedures\n");
                    imprimeErro(output);
                }
                sprintf(output,"CMDG");
                geraCodigo (NULL, output);
                 if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '!=' with INTEGER values\n");
                    imprimeErro(output);
                }
                //pop(auxStack);
                pop(auxStack);
            }
            | expressao_associativa MAIOR expressao_comutativa {
                char output[64];
                composedExpression = 1;
                if (procedureCall) {
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
                //pop(auxStack);
                pop(auxStack);
            }
            | expressao_associativa MENOR expressao_comutativa {
                char output[64];
                composedExpression = 1;
                if (procedureCall) {
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

                //pop(auxStack);
                pop(auxStack);
            }
            | expressao_associativa MAIOR_IGUAL expressao_comutativa {
                char output[64];
                composedExpression = 1;
                if (procedureCall) {
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
                //pop(auxStack);
                pop(auxStack);
            }
            | expressao_associativa MENOR_IGUAL expressao_comutativa {
                char output[64];
                composedExpression = 1;
                if (procedureCall) {
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
                //pop(auxStack);
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
                    if (procedureCall) {
                        sprintf(output, "cannot operate '+' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '+'\n");
                            imprimeErro(output);
                        }
                        //pop(auxStack);   
                    }                                  
                    sprintf(output,"SOMA");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;
                    pop(auxStack);
                }
                | expressao_associativa SUBTRACAO expressao_comutativa {
                    char output[64];
                    composedExpression = 1;
                    
                    if (procedureCall) {
                        sprintf(output, "cannot operate '-' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '-'\n");
                            imprimeErro(output);
                        }
                        //pop(auxStack);
                    }
                    sprintf(output,"SUBT");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;
                    
                    pop(auxStack);
                }
                | expressao_comutativa OR expressao_parenteses {
                    char output[64];
                    composedExpression = 1;

                    if (procedureCall) {
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
                        //pop(auxStack);  
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
                    if (procedureCall) {
                        sprintf(output, "cannot operate '*' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '*'\n");
                            imprimeErro(output);
                        }     
                        //pop(auxStack);     
                    }          
                    sprintf(output,"MULT");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;

                    pop(auxStack);
                }
                | expressao_comutativa DIVISAO_REAL expressao_parenteses {
                    char output[64];
                    composedExpression = 1;
                    if (procedureCall) {
                        sprintf(output, "cannot operate '/' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '/'\n");
                            imprimeErro(output);
                        }
                        //pop(auxStack);
                    }
                    sprintf(output,"DIVI");
                    geraCodigo (NULL, output);
                    pop(auxStack);
                }
                | expressao_comutativa DIVISAO expressao_parenteses {
                    char output[64];
                    composedExpression = 1;
                    if (procedureCall) {
                        sprintf(output, "cannot operate 'div' with procedures\n");
                        imprimeErro(output);
                    }
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate 'div'\n");
                            imprimeErro(output);
                        }
                        //pop(auxStack);
                    }
                    sprintf(output,"DIVI");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;                    
                    pop(auxStack);
                }
                | expressao_comutativa AND expressao_parenteses {
                    char output[64];
                    composedExpression = 1;
                    if (procedureCall) {
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
                         //pop(auxStack);
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
            hasBoolExpression = 0;
            hasIntExpression = 0;
            assignDetected = 0;

            char output[64];            
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

                sprintf(output,"ARMZ %d,%d", symbolsTable[index].lex_level, symbolsTable[index].offset);
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
        hasBoolExpression = 0;
        hasIntExpression = 0;
        assignDetected = 0;

        node *aux = malloc(sizeof(node));
        char output[64];

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

parametro_procedimento: IDENT {
                        char output[64];

                        // Checa se símbolo já está declarado na tabela de símbolos
                        for (int i = tablePosition; i >= 0; i--) {
                            if (strcmp(token, symbolsTable[i].symbol) == 0 && symbolsTable[i].lex_level == lex_level) {
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
                        symbolsTable[tablePosition].by_reference = BY_VALUE;  
                    } DOIS_PONTOS IDENT {
                        if (strcmp(token, "integer") == 0) {
                            symbolsTable[tablePosition].type = INTEGER;
                        }
                        else if (strcmp(token, "boolean") == 0) {
                            symbolsTable[tablePosition].type = BOOLEAN;
                        }
                        else {
                            char output[64];
                            sprintf(output, "unidentified type '%s'", token);
                            imprimeErro(output);
                        }
                    }
                    | VAR IDENT {
                        char output[64];

                        // Checa se símbolo já está declarado na tabela de símbolos
                        for (int i = tablePosition; i >= 0; i--) {
                            if (strcmp(token, symbolsTable[i].symbol) == 0 && symbolsTable[i].lex_level == lex_level) {
                                sprintf(output, "symbol '%s'  already declared as a parameters", token);
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
                        symbolsTable[tablePosition].by_reference = BY_REFERENCE;  

                    } DOIS_PONTOS IDENT {
                        if (strcmp(token, "integer") == 0) {
                            symbolsTable[tablePosition].type = INTEGER;
                        }
                        else if (strcmp(token, "boolean") == 0) {
                            symbolsTable[tablePosition].type = BOOLEAN;
                        }
                        else {
                            char output[64];
                            sprintf(output, "unidentified type '%s'", token);
                            imprimeErro(output);
                        }
                    }
;

parametros_procedimento: parametros_procedimento PONTO_E_VIRGULA parametro_procedimento
                        | parametro_procedimento 
;

parametros_formais: ABRE_PARENTESES parametros_procedimento FECHA_PARENTESES {
                        int procedureParamsOffset = -4;
                        int countParams = 0;
                        int procedureIndex = -1;

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

procedure: PROCEDURE IDENT {
            char output[64];  
            char output2[64];
                
            // Checa se símbolo já está declarado na tabela de símbolos
            for (int i = tablePosition; i >= 0; i--) {
                if (strcmp(token, symbolsTable[i].symbol) == 0 && symbolsTable[i].lex_level <= lex_level) {
                    sprintf(output, "symbol '%s'  already declared", token);
                    imprimeErro(output);
                }

                if (strcmp(token, symbolsTable[i].symbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && symbolsTable[i].lex_level == lex_level + 1) {
                    sprintf(output, "symbol '%s'  already declared as a procedure", token);
                    imprimeErro(output);
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

            offset = 0;
            num_vars = 0;            
            /* --------------------------------------------- */

            node *aux = malloc(sizeof(node));

            countProcedures++;
            
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

            labelNumber++;
        } parametros_formais PONTO_E_VIRGULA bloco {
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

            sprintf(output, "RTPR %d,%d", lex_level, symbolsTable[index].total_params + 1);
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
;

subrotina: procedure
            | funcao
;

procedures: procedures subrotina PONTO_E_VIRGULA
            | procedures PONTO_E_VIRGULA subrotina
            | procedures subrotina 
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
                                                            sprintf(output,"CREN %d,%d",symbolsTable[j].lex_level, symbolsTable[j].offset);
                                                            geraCodigo (NULL, output);
                                                            break;
                                                        }
                                                        else {
                                                            sprintf(output,"CRVL %d,%d",symbolsTable[j].lex_level, symbolsTable[j].offset);
                                                            geraCodigo (NULL, output);
                                                            break;
                                                        }
                                                    }
                                            }
                                        }
                                        else {
                                            if (composedExpression) {
                                                for (int j = tablePosition; j >= 0; j--) {
                                                    if (strcmp(aux->symbol, symbolsTable[j].symbol) == 0 && 
                                                        (symbolsTable[j].lex_level <= lex_level || symbolsTable[j].lex_level == lex_level + 1)) {
                                                        // if (symbolsTable[j].by_reference == BY_REFERENCE) {
                                                        //     sprintf(output,"CRVL %d,%d",symbolsTable[j].lex_level, symbolsTable[j].offset);
                                                        //     geraCodigo (NULL, output);
                                                        //     break;
                                                        // }
                                                    }
                                                }
                                            }
                                        }
                                        
                                    }
                                }

                                countProcedureParams++;
                                composedExpression = 0; 
                                constantVal = 0;                               
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
                                                            sprintf(output,"CREN %d,%d",symbolsTable[j].lex_level, symbolsTable[j].offset);
                                                            geraCodigo (NULL, output);
                                                            break;
                                                        }
                                                        else {
                                                            sprintf(output,"CRVL %d,%d",symbolsTable[j].lex_level, symbolsTable[j].offset);
                                                            geraCodigo (NULL, output);
                                                            break;
                                                        }
                                                    }
                                            }
                                
                                        }
                                        else {
                                            if (composedExpression) {
                                                for (int j = tablePosition; j >= 0; j--) {
                                                    if (strcmp(aux->symbol, symbolsTable[j].symbol) == 0 && 
                                                        (symbolsTable[j].lex_level <= lex_level || symbolsTable[j].lex_level == lex_level + 1)) {
                                                        // if (symbolsTable[j].by_reference == BY_REFERENCE) {
                                                        //     sprintf(output,"teste1CRVL %d,%d",symbolsTable[j].lex_level, symbolsTable[j].offset);
                                                        //     geraCodigo (NULL, output);
                                                        //     break;
                                                        // }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                countProcedureParams++;
                                composedExpression = 0;
                                constantVal = 0;
                            }
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

                                    if (symbolsTable[i].label  < 10) {
                                        sprintf(output,"CHPR R0%d,%d", symbolsTable[i].label, lex_level);
                                    }
                                    else {
                                        sprintf(output,"CHPR R%d,%d", symbolsTable[i].label, lex_level);
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

                                if (symbolsTable[i].label  < 10) {
                                    sprintf(output,"CHPR R0%d,%d", symbolsTable[i].label, lex_level);
                                }
                                else {
                                    sprintf(output,"CHPR R%d,%d", symbolsTable[i].label, lex_level);
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

funcao: FUNCTION IDENT {
            char output[64];  
            char output2[64];
                
            // Checa se símbolo já está declarado na tabela de símbolos
            for (int i = tablePosition; i >= 0; i--) {
                if (strcmp(token, symbolsTable[i].symbol) == 0 && symbolsTable[i].lex_level <= lex_level) {
                    sprintf(output, "symbol '%s'  already declared", token);
                    imprimeErro(output);
                }

                if (strcmp(token, symbolsTable[i].symbol) == 0 && (symbolsTable[i].def == IS_PROCEDURE || symbolsTable[i].def == IS_FUNCTION) && symbolsTable[i].lex_level == lex_level + 1) {
                    sprintf(output, "symbol '%s'  already declared as a procedure or function", token);
                    imprimeErro(output);
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

            offset = 0;
            num_vars = 0;
            
            /* --------------------------------------------- */

            node *aux = malloc(sizeof(node));

            countProcedures++;
            
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
        } PONTO_E_VIRGULA bloco {
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

            sprintf(output, "RTPR %d,%d", lex_level, symbolsTable[index].total_params + 1);
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
    varTypeStack = declareStack();
    assignVariables = declareStack();
    labels = declareStack();
    procedureLabels = declareStack();
    lastProcSymbol[0] = '\0';

   yyin=fp;
   yyparse();

   return 0;
}
