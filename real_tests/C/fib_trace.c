#include "test.h"

int call_count = 0;

int fib(int n) {
    call_count++;
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int main() {
    int result = fib(10);
    printf("fib(10) = %d\n", result);
    printf("Total calls: %d\n", call_count);
    return 0;
}