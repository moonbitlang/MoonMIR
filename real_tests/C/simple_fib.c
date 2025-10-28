void print_int(int n);

int fib(int n) {
    if (n <= 1) return n;
    int a = fib(n - 1);
    int b = fib(n - 2);
    return a + b;
}

int main() {
    int result = fib(10);
    print_int(result);
    return 0;
}
