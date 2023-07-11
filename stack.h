#ifndef _stack_
#define _stack_

#define MAX_SYMBOL_SIZE 32

typedef struct Node {
    struct Node *next;
    struct Node *previous;
    char symbol[MAX_SYMBOL_SIZE];
    int type;
    int label; // only for labels
    int isFunction; // only for procedures
    int checkParams;
    //int variable;
} node;

typedef struct Stack {
    node *bottom;
    node *top;
    int size;
} stack;

stack *declareStack();
void push(stack *stack, node *node);
void pop(stack *stack);
int countElements(stack *stack);

#endif