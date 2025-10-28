int fib(int n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int main() {
    if (fib(5) != 5) return 1;
    if (fib(6) != 8) return 2;
    if (fib(7) != 13) return 3;
    if (fib(8) != 21) return 4;
    if (fib(9) != 34) return 5;
    if (fib(10) != 55) return 6;
    return 0;
}