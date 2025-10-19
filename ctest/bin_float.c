#include "test.h"

int is_eqf(float actual, float expected) {
  if (expected == actual) {
    return 1;
  }
  return 0;
}

int is_eqd(double actual, double expected) {
  if (expected == actual) {
    return 1;
  }
  return 0;
}

int main() {
  int passed = 0;

  float a = 1.5f, b = 2.0f, c = 3.0f;
  passed += is_eqf(a + b, 3.5f);
  passed += is_eqf(c - b, 1.0f);
  passed += is_eqf(b - c, -1.0f);
  passed += is_eqf(a * b, 3.0f);
  passed += is_eqf(c / a, 2.0f);

  double da = 1.5, db = 2.0, dc = 3.0;
  passed += is_eqd(da + db, 3.5);
  passed += is_eqd(dc - db, 1.0);
  passed += is_eqd(db - dc, -1.0);
  passed += is_eqd(da * db, 3.0);
  passed += is_eqd(dc / da, 2.0);

  // Mixed float and double operations
  passed += is_eqf(a * c, 4.5f);
  passed += is_eqd(da * dc, 4.5);

  printf("%d\n", passed);
  return 0;
}
