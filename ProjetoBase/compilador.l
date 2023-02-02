
/* -------------------------------------------------------------------
 *            Arquivo: compilador.l
 * -------------------------------------------------------------------
 *              Autor: Bruno Muller Junior
 *               Data: 08/2007
 *      Atualizado em: [09/08/2020, 19h:01m]
 *
 * -------------------------------------------------------------------
 *
 * Tipos, protótipos e variáveis globais do compilador (via extern)
 *
 * ------------------------------------------------------------------- */

%{


#include<stdio.h>
#include<string.h>

#include "compilador.h"
#include "compilador.tab.h"

//#define IMPRIME(STR) {};
#define IMPRIME(STR) printf("%s    # %s \n", STR, token);

int nl = 1;

%}

pulo_linha [\n]

descarte [\t ]+

ident [a-zA-Z][a-zA-Z0-9]*

numero [0-9]+

comentario "(*".*"*)"

%%

{pulo_linha} {nl++;}

{descarte}

{comentario}

program { simbolo  = simb_program;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME("program ");
        return PROGRAM;
 }

var { simbolo = simb_var;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME("var  ");
        return VAR;
}

array { simbolo = simb_array;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME("array  ");
        return ARRAY;
}

procedure { simbolo = simb_procedure;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME("procedure  ");
        return PROCEDURE;
}

function { simbolo = simb_function;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME("function  ");
        return FUNCTION;
}

while { simbolo = simb_while;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME("while  ");
        return WHILE;
}

if { simbolo = simb_if;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME("if  ");
        return IF;
}

begin { simbolo = simb_begin;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME("begin ");
        return T_BEGIN;
}

end { simbolo = simb_end;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME("end  ");
        return T_END;
}

:= { simbolo = simb_atribuicao;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" atribuicao  ");
        return ATRIBUICAO;
}

\; { simbolo = simb_ponto_e_virgula;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" pt_virgula  ");
        return PONTO_E_VIRGULA;
}

\: { simbolo = simb_dois_pontos;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" dois pontos ");
        return DOIS_PONTOS;
}

\, { simbolo = simb_virgula;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" virgula  ");
        return VIRGULA;
}


\. { simbolo = simb_ponto;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" ponto  ");
        return PONTO;
}

\(  { simbolo = simb_abre_parenteses;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" abre_parenteses  ");
        return ABRE_PARENTESES;
}

\)  { simbolo = simb_fecha_parenteses;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" fecha_parenteses ");
        return FECHA_PARENTESES;
 }


\/ { simbolo = simb_divisao_real;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_divisao_real ");
        return DIVISAO_REAL;
}

div { simbolo = simb_divisao;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_divisao ");
        return DIVISAO;
}

\+ { simbolo = simb_adicao;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_adicao ");
        return ADICAO;
}

\- { simbolo = simb_subtracao;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_subtracao ");
        return SUBTRACAO;
}

\* { simbolo = simb_multiplicacao;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_multiplicacao ");
        return MULTIPLICACAO;
}

mod { simbolo = simb_mod;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_mod ");
        return MOD;
}

and { simbolo = simb_and;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_and ");
        return AND;
}

or { simbolo = simb_or;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_or ");
        return OR;
}

xor { simbolo = simb_xor;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_xor ");
        return XOR;
}

\= { simbolo = simb_igual;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_igual ");
        return IGUAL;
}

\<> { simbolo = simb_diferente;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_diferente ");
        return DIFERENTE;
}

\> { simbolo = simb_maior;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_maior ");
        return MAIOR;
}

\< { simbolo = simb_menor;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_menor ");
        return MENOR;
}

\>= { simbolo = simb_maior_igual;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_maior_igual ");
        return MAIOR_IGUAL;
}

\<= { simbolo = simb_menor_igual;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_menor_igual ");
        return MENOR_IGUAL;
}

in { simbolo = simb_in;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_in ");
        return IN;
}


\# { simbolo = simb_hash;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_hash ");
        return HASH;
}

\' { simbolo = simb_aspa_simples;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_aspa_simples ");
        return ASPA_SIMPLES;
}

\$ { simbolo = simb_cifrao;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_cifrao ");
        return CIFRAO;
}

\.. { simbolo = simb_intervalo;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_intervalo ");
        return INTERVALO;
}

\[ { simbolo = simb_abre_colchetes;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_abre_colchetes ");
        return ABRE_COLCHETES;
}

\] { simbolo = simb_fecha_colchetes;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_fecha_colchetes ");
        return FECHA_COLCHETES;
}

\{ { simbolo = simb_abre_chaves;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_abre_chaves ");
        return ABRE_CHAVES;
}

\} { simbolo = simb_fecha_chaves;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_fecha_chaves ");
        return FECHA_CHAVES;
}

false { simbolo = simb_falso;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_falso ");
        return FALSO;
}

true { simbolo = simb_verdadeiro;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_verdadeiro ");
        return VERDADEIRO;
}

do { simbolo = simb_do;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_do ");
        return DO;
}

read { simbolo = simb_read;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_read ");
        return READ;
}

write { 
        simbolo = simb_write;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_write ");
        return WRITE;
}

then { 
        simbolo = simb_then;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_then ");
        return THEN;
}

else { 
        simbolo = simb_else;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" simb_else ");
        return ELSE;
}

{numero} {
        simbolo = simb_numero;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" numero  ");
        return NUMERO;
}

{ident} { simbolo = simb_identificador;
        strncpy (token, yytext, TAM_TOKEN);
        IMPRIME(" ident  ");
        return IDENT;
}


%%
