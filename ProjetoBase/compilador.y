
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
stack *identTypes;
stack *labels;

int hasBoolExpression = 0;
int hasIntExpression = 0;

int assignDetected = 0;

int labelNumber = 0;

int needWrite = 0;
int needRead = 0;
int ifExpression = 0;
int whileExpression = 0;

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
                auxStack = declareStack();
                varTypeStack = declareStack();
                assignVariables = declareStack();
                labels = declareStack();
             }
             PROGRAM IDENT
             ABRE_PARENTESES lista_idents FECHA_PARENTESES PONTO_E_VIRGULA 
             bloco  PONTO {
                if (tablePosition >= 0) {
                    char output[64];
                    sprintf(output,"DMEM %d",tablePosition + 1);
                    geraCodigo (NULL, output);

                    tablePosition = -1;
                }

                geraCodigo (NULL, "PARA");
             }
;

bloco       : parte_declara_vars procedure comando_composto
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
                tipo
                {
                    if (num_vars > 0) {
                        char output[64];
                        sprintf(output,"AMEM %d",num_vars);
                        geraCodigo (NULL, output);
                    }

                    num_vars = 0;
                }
                PONTO_E_VIRGULA
;

tipo        : IDENT
            {                
                //printf("\n\n\n\naqui %s\n\n\n", token);                
                int index = tablePosition;
                int count = 0;

                //printf("%d\n\n", tablePosition);

                while(count < num_vars) {
                    if (strcmp(token, "integer") == 0) {
                        //printf("\n\n\n\naqui %s integer\n\n\n", symbolsTable[index].symbol);
                        symbolsTable[index].type = INTEGER;
                    }
                    else if (strcmp(token, "boolean") == 0) {
                        printf("\n\n\n\naqui %s boolean\n\n\n", symbolsTable[index].symbol);
                        symbolsTable[index].type = BOOLEAN;
                    }

                    index--;
                    count++;
                }

                //printf("\n\n\n\nteste123 %s", token);
            }
;

lista_id_var: lista_id_var VIRGULA IDENT
              { /* insere �ltima vars na tabela de s�mbolos */ 


                tablePosition++;
                strcpy(symbolsTable[tablePosition].symbol, token);
                symbolsTable[tablePosition].lex_level = lex_level;
                symbolsTable[tablePosition].offset = offset;

                //printf("\n\n\n\naqui %s\n\n\n", symbolsTable[tablePosition].symbol);    

                offset++;
                num_vars++;
              }
            | IDENT { /* insere vars na tabela de s�mbolos */
                tablePosition++;
                strcpy(symbolsTable[tablePosition].symbol, token);
                symbolsTable[tablePosition].lex_level = lex_level;
                symbolsTable[tablePosition].offset = offset;

                //printf("\n\n\n\naqui %s\n\n\n", symbolsTable[tablePosition].symbol);    

                offset++;
                num_vars++;

                 //printf("\n\n\n\naqui %s\n\n\n", token);
            }
;

atribuicao:   
            variavel ATRIBUICAO constante
            {

                if (assignVariables->top->type != auxStack->top->type) {
                    char output[64];
                    sprintf(output, "trying to assign value of different type to variable '%s'\n", assignVariables->top->symbol);
                    imprimeErro(output);
                }

                int index = 0;
                //printf("\n\n\n\n teste1 %s\n\n", last_ident.token);
                while(strcmp(symbolsTable[index].symbol, last_ident.token) != 0) {
                    if (index > tablePosition) {
                        break;
                    }     
                    index++;               
                }

                char output[64];

                if (index <= tablePosition) {
                    //printf("\n\n\n\n\nsimbolo encontrado na TS: %s\n\n\n\n\n\n\n", symbolsTable[index].symbol);
                    sprintf(output,"ARMZ %d,%d", lex_level, symbolsTable[index].offset);
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

                if (assignVariables->top->type != aux->type) {
                    char output[64];
                    sprintf(output, "trying to assign value of different type to variable '%s'\n", assignVariables->top->symbol);
                    imprimeErro(output);
                }

                int index = 0;
                char output[64];
                aux = aux->previous;
                while (index <= tablePosition) {
                    if (strcmp(symbolsTable[index].symbol, aux->symbol) == 0) {
                        break;
                    }

                    index++;
                }

                if (index <= tablePosition) {
                    sprintf(output,"ARMZ %d,%d", lex_level, symbolsTable[index].offset);
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
            | variavel ATRIBUICAO expressao
            {
                //printf("\n\n\n\n\n symbol %s \n\n\n\n\n", auxStack->top->symbol);
                if (hasBoolExpression) {
                    //printf("\n\n\n\n %s variable of type %d \n\n\n\n", assignVariables->top->symbol, assignVariables->top->type);
                    if (assignVariables->top->type != BOOLEAN) {
                        char output[64];
                        sprintf(output, "trying to assign BOOLEAN expression to variable '%s' of type INTEGER\n", assignVariables->top->symbol);
                        imprimeErro(output);
                    }
                }
                if (assignVariables->top->type == BOOLEAN && !hasBoolExpression) {
                        char output[64];
                        sprintf(output, "trying to assign NOT BOOLEAN value to variable '%s' of type BOOLEAN\n", assignVariables->top->symbol);
                        imprimeErro(output);
                }

                int index = 0;
                while(strcmp(symbolsTable[index].symbol, assignVariables->top->symbol) != 0 && index <= tablePosition) {
                    // if (index > tablePosition) {
                    //     break;
                    // }     
                    index++;
                }

                char output[64];
                if (index <= tablePosition) {
                    //printf("\n\n\n\n\nsimbolo encontrado na TS: %s\n\n\n\n\n\n\n", symbolsTable[index].symbol);
                    sprintf(output,"ARMZ %d,%d", lex_level, symbolsTable[index].offset);
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
;

variavel: IDENT 
        {
            //printf("\n\nvariável %s detectada\n\n", token);
            node *aux = malloc(sizeof(node));
            strcpy(aux->symbol, token);

            //printf ("\n\n\n símbolo encontrado %s \n\n\n\n", aux->symbol);

            // busca o símbolo na tabela de símbolos para poder identificar o tipo
            int index = 0;
            char output[64];
            while (index <= tablePosition) {
                if (strcmp(symbolsTable[index].symbol, token) == 0) {
                    break;
                }
                
                index++;
            }

            if (index <= tablePosition) {
                aux->type = symbolsTable[index].type;
            }
            else {
                sprintf(output, "symbol not declared '%s' identified\n", aux->symbol);
                imprimeErro(output);
            }
            push(auxStack, aux);
            strcpy(last_ident.token, token);

            if (assignDetected) {
                node *aux2 = malloc(sizeof(node));
                aux2->type = auxStack->top->type;
                strcpy(aux2->symbol, auxStack->top->symbol);

                push(assignVariables, aux2);
            }

            if (!assignDetected) {
                aux = auxStack->top;

                index = 0;
                while (index <= tablePosition) {
                    if (strcmp(symbolsTable[index].symbol, aux->symbol) == 0) {
                        // printf ("\n\n\n símbolo encontrado %s \n\n\n\n", aux->symbol);
                        // printf("\n\n\n hasbool %d\n\n\n\n", hasBoolExpression);
                        break;
                    }
                    
                    index++;
                }

                if (index > tablePosition) {
                    sprintf(output, "symbol not declared '%s' identified\n", aux->symbol);
                    imprimeErro(output);
                }

                sprintf(output,"CRVL %d,%d", lex_level, symbolsTable[index].offset);
                geraCodigo (NULL, output);
            }

            assignDetected = 0;
        }
;

constante:  NUMERO {
                //printf("\n\n\n\n\nencontrou constante: %s\n\n\n\n\n\n\n", token);
                // empilha constante para poder identificar tipagem
                node *aux = malloc(sizeof(node));
                strcpy(aux->symbol, token);
                aux->type = INTEGER;
                push(auxStack, aux);

                char output[64];
                sprintf(output,"CRCT %s", token);
                geraCodigo (NULL, output);
            }
            | FALSO {
                // empilha constante para poder identificar tipagem
                node *aux = malloc(sizeof(node));
                strcpy(aux->symbol, token);
                aux->type = BOOLEAN;
                push(auxStack, aux);

                char output[64];
                sprintf(output,"CRCT %d", 0);
                geraCodigo (NULL, output);
            }
            | VERDADEIRO {
                //printf("\n\n\n\n\nencontrou constante: %s\n\n\n\n\n\n\n", token);
                // empilha constante para poder identificar tipagem
                node *aux = malloc(sizeof(node));
                strcpy(aux->symbol, token);
                aux->type = BOOLEAN;
                push(auxStack, aux);

                char output[64];
                sprintf(output,"CRCT %d", 1);
                geraCodigo (NULL, output);
            }
;

expressao: expressao_associativa IGUAL expressao_comutativa {
                char output[64];
                sprintf(output,"CMIG");
                geraCodigo (NULL, output);
                 if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '=' with INTEGER values\n");
                    imprimeErro(output);
                }
                pop(auxStack);
                pop(auxStack);
            }
            | expressao_associativa DIFERENTE expressao_comutativa {
                char output[64];
                sprintf(output,"CMDG");
                geraCodigo (NULL, output);
                 if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '!=' with INTEGER values\n");
                    imprimeErro(output);
                }
                pop(auxStack);
                pop(auxStack);
            }
            | expressao_associativa MAIOR expressao_comutativa {
                char output[64];
                sprintf(output,"CMMA");
                geraCodigo (NULL, output);
                hasBoolExpression = 1;
                 if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '>' with INTEGER values\n");
                    imprimeErro(output);
                }
                pop(auxStack);
                pop(auxStack);
            }
            | expressao_associativa MENOR expressao_comutativa {
                char output[64];
                sprintf(output,"CMME");
                geraCodigo (NULL, output);
                hasBoolExpression = 1;
                if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '<' with INTEGER values\n");
                    imprimeErro(output);
                }

                pop(auxStack);
                pop(auxStack);
            }
            | expressao_associativa MAIOR_IGUAL expressao_comutativa {
                char output[64];
                sprintf(output,"CMAG");
                geraCodigo (NULL, output);
                hasBoolExpression = 1;
                 if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '>=' with INTEGER values\n");
                    imprimeErro(output);
                }
                pop(auxStack);
                pop(auxStack);
            }
            | expressao_associativa MENOR_IGUAL expressao_comutativa {
                char output[64];
                sprintf(output,"CMEG");
                geraCodigo (NULL, output);
                hasBoolExpression = 1;
                 if ((auxStack->top->type != BOOLEAN && auxStack->top->previous->type == BOOLEAN) || (auxStack->top->type == BOOLEAN && auxStack->top->previous->type != BOOLEAN)) {
                    sprintf(output, "BOOLEAN values are not allowed to operate '<=' with INTEGER values\n");
                    imprimeErro(output);
                }
                pop(auxStack);
                pop(auxStack);
            }
            | expressao_associativa
            | expressao_comutativa
            | expressao_parenteses
            | constante
            | variavel
;

expressao_associativa: expressao_associativa ADICAO expressao_comutativa {
                    //printf("SOMANDO\n");
                    // printf("\n\n\n qual ultimo ident: %s \n\n\n", auxStack->top->symbol);
                    // printf("\n\n\n qual penultimo ident: %s \n\n\n", auxStack->top->previous->symbol);
                    char output[64];
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '+'\n");
                            imprimeErro(output);
                        }
                        pop(auxStack);   
                    }                                  
                    sprintf(output,"SOMA");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;
                    pop(auxStack);
                }
                | expressao_associativa SUBTRACAO expressao_comutativa {
                    char output[64];
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '-'\n");
                            imprimeErro(output);
                        }
                        pop(auxStack);
                    }
                    sprintf(output,"SUBT");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;
                    
                    pop(auxStack);
                }
                | expressao_comutativa OR expressao_parenteses {
                    char output[64];
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == INTEGER || auxStack->top->previous->type == INTEGER) {
                            if (!whileExpression && !ifExpression) {
                                sprintf(output, "INTEGER values are not allowed to operate 'or'\n");
                                imprimeErro(output);
                            }
                        }     
                        pop(auxStack);  
                    }             
                    sprintf(output,"DISJ");
                    geraCodigo (NULL, output);
                    hasBoolExpression = 1;                    
                    pop(auxStack);
                }
                | expressao_comutativa
;

expressao_comutativa: expressao_comutativa MULTIPLICACAO expressao_parenteses {
                    //printf("MULTIPLICANDO\n");
                    // printf("\n\n\n qual ultimo ident: %s \n\n\n", auxStack->top->symbol);
                    // printf("\n\n\n qual penultimo ident: %s \n\n\n", auxStack->top->previous->symbol);
                    // printf("tamanho da pilha = %d\n\n", countElements(auxStack));
                    char output[64];
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '*'\n");
                            imprimeErro(output);
                        }     
                        pop(auxStack);     
                    }          
                    sprintf(output,"MULT");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;

                    pop(auxStack);
                }
                | expressao_comutativa DIVISAO_REAL expressao_parenteses {
                    // printf("\n\n\n qual ultimo ident: %d \n\n\n", auxStack->top->type);
                    // printf("\n\n\n qual penultimo ident: %s \n\n\n", auxStack->top->previous->symbol);
                    // printf("tamanho da pilha = %d\n\n", countElements(auxStack));
                    char output[64];
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate '/'\n");
                            imprimeErro(output);
                        }
                        pop(auxStack);
                    }
                    sprintf(output,"DIVI");
                    geraCodigo (NULL, output);
                    pop(auxStack);
                }
                | expressao_comutativa DIVISAO expressao_parenteses {
                    char output[64];
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == BOOLEAN || auxStack->top->previous->type == BOOLEAN) {
                            sprintf(output, "BOOLEAN values are not allowed to operate 'div'\n");
                            imprimeErro(output);
                        }
                        pop(auxStack);
                    }
                    sprintf(output,"DIVI");
                    geraCodigo (NULL, output);
                    hasIntExpression = 1;                    
                    pop(auxStack);
                }
                | expressao_comutativa AND expressao_parenteses {
                    char output[64];
                    if (countElements(auxStack) > 2) {
                        if (auxStack->top->type == INTEGER || auxStack->top->previous->type == INTEGER) {
                            if (!whileExpression && !ifExpression) {
                                sprintf(output, "INTEGER values are not allowed to operate 'and'\n");
                                imprimeErro(output);
                            }
                        }
                         pop(auxStack);
                    }
                    sprintf(output,"CONJ");
                    geraCodigo (NULL, output);
                    hasBoolExpression = 1;                   ;
                    pop(auxStack);
                }
                | expressao_parenteses
                | constante
                | variavel
;

expressao_parenteses: ABRE_PARENTESES expressao FECHA_PARENTESES
                | constante
                | variavel
;

lista_idents: lista_idents VIRGULA IDENT
            | IDENT
;

comando_composto: T_BEGIN  comandos T_END
;

comandos: comandos comando PONTO_E_VIRGULA
            | comandos comando
            | comando PONTO_E_VIRGULA
            | comando
;

while:  {
            assignDetected = 0;
            hasBoolExpression = 0;
            hasIntExpression = 0;
            whileExpression = 0;

            if (labelNumber > 0) {
                labelNumber++;
            }

            char output[64];
            char output2[64];
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

parametro: IDENT {
            int index = 0;
            char output[64];
            while (index <= tablePosition) {
                if (strcmp(symbolsTable[index].symbol, token) == 0) {
                    break;
                }
                
                index++;
            }

            if (index > tablePosition) {
                sprintf(output, "symbol not declared '%s' identified\n", token);
                imprimeErro(output);
            }

            if (needRead) {
                char output[64];
                sprintf(output,"LEIT");
                geraCodigo (NULL, output);

                sprintf(output,"ARMZ %d,%d", lex_level, symbolsTable[index].offset);
                geraCodigo (NULL, output);
            }

            if (needWrite) {
                sprintf(output,"CRVL %d,%d", lex_level, symbolsTable[index].offset);
                geraCodigo (NULL, output);

                char output[64];
                sprintf(output,"IMPR");
                geraCodigo (NULL, output);
            }
        } 
        | NUMERO {
            char output[64];

            if (needRead) {
                sprintf(output, "Trying to read a constant value\n");
                imprimeErro(output);
            }

            if (needWrite) {
                sprintf(output,"CRCT %s", token);
                geraCodigo (NULL, output);

                char output[64];
                sprintf(output,"IMPR");
                geraCodigo (NULL, output);
            }
        }
;
parametros: parametro VIRGULA parametro
            | parametro 
;

outros_comandos: READ {
                    needRead = 1;
                } ABRE_PARENTESES 
                parametros FECHA_PARENTESES  {
                    needRead = 0;
                }
                | WRITE {
                    needWrite = 1;
                } ABRE_PARENTESES 
                parametros FECHA_PARENTESES {
                    needWrite = 0;
                }
;

if_then: IF {
            ifExpression = 1;
        } expressao {
        hasBoolExpression = 0;
        hasIntExpression = 0;
        assignDetected = 0;

        node *aux = malloc(sizeof(node));
        aux->label = labelNumber;
        push(labels, aux);

        labelNumber++;

        char output[64];
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
    } 
    THEN comando {
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

else: ELSE comando
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

if: if_then else
;


procedure: PROCEDURE IDENT PONTO_E_VIRGULA bloco 
            |
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

   yyin=fp;
   yyparse();

   return 0;
}
