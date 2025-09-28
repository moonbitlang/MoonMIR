
#include "test.h"

int sum(int begin, int end) {
  int total = 0;
  for (int i = begin; i <= end; i++) {
      total += i;
  }
  return total;
}

int main() {
  int result = sum(1, 100);
  printf("%d\n", result);
  return 0;
}
