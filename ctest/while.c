
void print_int(int i);

int main() {
  int i = 0;
  int sum = 0;
  while (i < 10) {
    i += 1;
    sum += i;
  }
  print_int(sum);
  return 0;
}
