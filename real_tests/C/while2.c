
#include "test.h"

void print_a_int(int i) {
  printf("%d ", i);
}

void print_endline() {
  printf("\n");
}

int main() {
  int i = 0;
  while (i < 10) {
    print_a_int(i);
    i = i + 1;
  }
  print_endline();
  return 0;
}
