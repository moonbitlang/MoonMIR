
#include "test.h"

int foo(int a, int b, int c, int d) {
  int res = a + b + c + d;
  return res;
}

int bar(int a, int b, int c, int d) {
  return foo(c, b, d, a);
}

int main() {
  int res = bar(1, 2, 3, 4);
  printf("%d\n", res);
  return 0;
}
