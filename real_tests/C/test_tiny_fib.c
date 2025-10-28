int fib(int n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int main() {
    // Test base cases
    if (fib(0) != 0) return 100;
    if (fib(1) != 1) return 101;
    
    // Test fib(2) = fib(1) + fib(0) = 1 + 0 = 1
    if (fib(2) != 1) return 102;
    
    // Test fib(3) = fib(2) + fib(1) = 1 + 1 = 2
    if (fib(3) != 2) return 103;
    
    return fib(3); // Should return 2
}