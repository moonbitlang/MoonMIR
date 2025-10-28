#include "test.h"

int fib(int n) {
  if (n <= 1) {
      return n;
  }
  return fib(n - 1) + fib(n - 2);
}

int main() {
  printf("fib(5) = %d\n", fib(5));
  printf("fib(6) = %d\n", fib(6));
  printf("fib(7) = %d\n", fib(7));
  printf("fib(8) = %d\n", fib(8));
  printf("fib(9) = %d\n", fib(9));
  printf("fib(10) = %d\n", fib(10));
  return 0;
}