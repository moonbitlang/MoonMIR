#include "test.h"

int add(int a, int b) {
    return a + b;
}

int main() {
    int result = add(34, 21);
    printf("%d\n", result);
    return 0;
}