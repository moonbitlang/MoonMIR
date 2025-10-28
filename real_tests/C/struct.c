
#include "test.h"


typedef struct {
  int x;
  int y;
} Point;

int main() {
  Point p1 = {10, 20};

  int s = p1.x + p1.y;

  printf("%d\n", s); // Expected output: 30
  return 0;
}
