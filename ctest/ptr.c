
#include "test.h"

void print_ptr_int(int* p) {
  printf("%d\n", *p);
}

int main() {
  int a = 42;
  print_ptr_int(&a);
  return 0;
}
