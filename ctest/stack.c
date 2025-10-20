#include "test.h"

#define NULL 0
#define MAX_SIZE 100

struct Stack {
    int top;
    unsigned capacity;
    int* array;
};

struct Stack* createStack(unsigned capacity) {
    struct Stack* stack = (struct Stack*) malloc(sizeof(struct Stack));
    stack->capacity = capacity;
    stack->top = -1;
    stack->array = (int*) malloc(stack->capacity * sizeof(int));
    return stack;
}

int isFull(struct Stack* stack) {
    return stack->top == stack->capacity - 1;
}

int isEmpty(struct Stack* stack) {
    return stack->top == -1;
}

void push(struct Stack* stack, int item) {
    if (isFull(stack)) {
        print_str("Stack overflow\n");
        return;
    }
    stack->array[++stack->top] = item;
    print_int(item);
    print_str("pushed to stack\n");
}

int pop(struct Stack* stack) {
    if (isEmpty(stack)) {
        print_str("Stack underflow\n");
        return -1; // Return a sentinel value for error
    }
    return stack->array[stack->top--];
}

int peek(struct Stack* stack) {
    if (isEmpty(stack)) {
        return -1; // Return a sentinel value for error
    }
    return stack->array[stack->top];
}

int main() {
    struct Stack* stack = createStack(MAX_SIZE);

    push(stack, 10);
    push(stack, 20);
    push(stack, 30);

    print_int(pop(stack));
    print_str(" popped from stack\n");
    print_str("Top element is ");
    print_int(peek(stack));
    newline();
    print_int(pop(stack));
    print_str("popped from stack\n");

    push(stack, 40);
    print_str("Top element is");
    print_int(peek(stack));
    newline();
    
    free(stack->array);
    free(stack);

    return 0;
}
