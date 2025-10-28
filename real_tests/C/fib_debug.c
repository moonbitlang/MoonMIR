#include "test.h"

int fib(int n) {
  printf("fib(%d) called\n", n);
  if (n <= 1) {
      printf("fib(%d) returning %d\n", n, n);
      return n;
  }
  int r1 = fib(n - 1);
  int r2 = fib(n - 2);
  int result = r1 + r2;
  printf("fib(%d) = fib(%d) + fib(%d) = %d + %d = %d\n", n, n-1, n-2, r1, r2, result);
  return result;
}

int main() {
  int n = 5; // Smaller example
  int result = fib(n);
  printf("Final result: %d\n", result);
  return 0;
}