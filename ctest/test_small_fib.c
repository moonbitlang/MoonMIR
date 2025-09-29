int fib(int n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int main() {
    if (fib(0) != 0) return 10;
    if (fib(1) != 1) return 11;
    if (fib(2) != 1) return 12;
    if (fib(3) != 2) return 13;
    if (fib(4) != 3) return 14;
    if (fib(5) != 5) return 15;
    return 0;
}