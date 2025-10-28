int fib(int n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int main() {
    // fib(4) = fib(3) + fib(2) = 2 + 1 = 3
    return fib(4);
}