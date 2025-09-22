# Kaida-Amethyst/GMIR

## How To Use

1. Install `riscv64-gnu-toolchain`  riscv64-unknown-elf-gcc

2. Install `spike`

3. Compile C

```
moon run mbtcc -- --file ctest/simple_ret.c -o ret.s
```

4. `riscv64-unknown-elf-gcc ret.s runtime.c -o ret` (for ret.s, no need runtime.c actually)

5. `spike pk ret`, the use `echo $?` to check the result
