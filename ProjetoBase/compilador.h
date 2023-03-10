/* -------------------------------------------------------------------
 *            Arquivo: compilador.h
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

/*
Alunos:
    Wendel Caio Moro GRR20182641
    Bruno Augusto Luvizott GRR20180112
    Atualizado em: [23/02/2022]
*/

#define TAM_TOKEN 32


typedef enum simbolos {
    simb_program, simb_var, simb_begin, simb_end,
    simb_identificador, simb_numero,
    simb_ponto, simb_virgula, simb_ponto_e_virgula, simb_dois_pontos,
    simb_atribuicao, simb_abre_parenteses, simb_fecha_parenteses,
    simb_divisao_real, simb_divisao, simb_adicao, simb_subtracao,
    simb_multiplicacao, simb_mod, simb_and, simb_or, simb_xor,
    simb_diferente, simb_maior, simb_menor, simb_maior_igual, simb_menor_igual,
    simb_in, simb_hash, simb_aspa_simples, simb_cifrao, simb_intervalo,
    simb_abre_colchetes, simb_fecha_colchetes, simb_abre_chaves,
    simb_fecha_chaves, simb_array, simb_procedure, simb_function, simb_while,
    simb_if, simb_igual, simb_falso, simb_verdadeiro, simb_do, simb_read, simb_write,
    simb_then, simb_else, simb_forward
} simbolos;

typedef struct Param {
    int type;
    int by_reference;
} Param;

// Elemento da tabela de símbolos
typedef struct Symbol {
    char symbol[TAM_TOKEN];
    int type;
    int lex_level;
    int offset;

    /* Variável simples| Procedimento | Parâmetro Formal | Função */
    int def;

    /* Referência ou valor */
    int by_reference;
    int parameter_foward;
    int paramIndex;

    /* Rotulo */
    int label;
    /* Em caso de procedimentos, utiliza um vetor de parâmetros  e uma contagem de parâmetros */
    int total_params;
    struct Param params[1024];

    // Procedimento em caso de haver foward
    int hasFoward;
    int fowardedLabel;
    int fowarded;
} Symbol;

typedef struct identType {
    char token[TAM_TOKEN];
    int isVar;
    int type;
} identType;


/* -------------------------------------------------------------------
 * variáveis globais
 * ------------------------------------------------------------------- */

extern simbolos simbolo, relacao;
extern char token[TAM_TOKEN];
// extern int nivel_lexico;
// extern int desloc;
extern int nl;


/* -------------------------------------------------------------------
 * prototipos globais
 * ------------------------------------------------------------------- */

void geraCodigo (char*, char*);
int imprimeErro ( char* erro );
int yylex();
void yyerror(const char *s);
