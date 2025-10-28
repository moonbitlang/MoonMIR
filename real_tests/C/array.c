
#include "test.h"

int sum(int *arr, int size) {
  int total = 0;
  for (int i = 0; i < size; i++) {
    total += arr[i];
  }
  return total;
}

int main() {
  int arr[5] = {1, 2, 3, 4, 5};
  int s = sum(arr, 5);
  printf("%d\n", s); // Expected output: 15
  return 0;
}
