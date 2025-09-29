#include "test.h"

int fib(int n) {
  if (n <= 1) {
      return n;
  }
  int r1 = fib(n - 1);
  int r2 = fib(n - 2); 
  return r1 + r2;
}

int main() {
  for (int i = 0; i <= 10; i++) {
    printf("fib(%d) = %d\n", i, fib(i));
  }
  return 0;
}