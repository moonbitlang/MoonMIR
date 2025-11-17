# MoonMIR

This Library is for compiling llvm IR from MoonLLVM to assembly code.

Currently, it could compile llvm Module to riscv64 and aarch64.

## Usage

In your MoonLLVM Project, use `moon update` to update package index first,

then use `moon add Kaida-Amethyst/MoonMIR` add MoonMIR to your project.

then in the package you want to use MoonMIR, add specified target under your moon.pkg.json.

for example, if you want to compile your llvm module to riscv64 assembly,

you add `Kaida-Amethyst/MoonMIR/riscv64`， under your moon.pkg.json, under `imports` item.

then in your code, use `@riscv64.compile`, you will get the riscv64 module, you can just print it.

## Examples

In a new package, first use `moon update`,

then use `moon add Kaida-Amethyst/MoonLLVM` and `moon add Kaida-Amethyst/MoonMIR`.

then in the main package, write moon.pkg.json:

```json
{
  "imports": [
    "Kaida-Amethyst/MoonLLVM/IR",
    "Kaida-Amethyst/MoonMIR/riscv64",
  ]
}
```

(You can also use `aarch64`)

then in your main.mbt, use `@IR` and `@riscv64.compile`.

```moonbit
fn main_err() -> Unit raise {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("my_module")
  let builder = IRBuilder::new()

  let i32_t = ctx.getInt32Ty()
  let f_type = ctx.getFunctionType(i32_t, [i32_t, i32_t])

  let f = mod.addFunction(f_type, "add")
  let bb = f.addBasicBlock("entry")
  builder.setInsertPoint(bb)

  let x = f.getArg(0).unwrap()
  x.setName("x")
  let y = f.getArg(1).unwrap()
  y.setName("y")

  let sum = builder.createAdd(x, y, "sum")
  builder.createRet(sum)

  let rv_mod = @riscv64.compile(mod) // <----

  println(rv_mod)
}

fn main {
  try main_err() catch {
    e => println(e)
  } noraise {
    _ => ()
  }
}
```

## Future Plan

1. More Backends, like x86_64
2. MoonAs and MoonLD，Assembler and Linker.
3. Support Debugger.
4. and more...
