
#include "test.h"

int sum(int* arr, int size) {
  int total = 0;
  for (int i = 0; i < size; i++) {
    total += arr[i];
  }
  return total;
}

int main() {
  int* arr = (int*)malloc(5 * sizeof(int));
  for (int i = 0; i < 5; i++) {
    arr[i] = i + 1; // Initialize array with values 1 to 5
  }
  int result = sum(arr, 5);
  printf("%d\n", result); // Should print 15
  free(arr);
  return 0;
}
