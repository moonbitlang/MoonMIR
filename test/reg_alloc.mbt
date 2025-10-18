///|
test "Simple Insts Live Analysis" {
  let code =
    #|fn foo(x: Int, y: Int) -> Int {
    #|  let a = x + y;
    #|  let b = x - y;
    #|  let c = a * b;
    #|  let d = a / b;
    #|  let e = c % d;
    #|  e
    #|}
  let llvm_mod = @TinyMoonBit.compile(code)

  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("foo").unwrap()
  // Register Allocation
  mir_func.alloc_register()
  let expected =
    #|func foo(a0, a1) {
    #|entry:                       ; live in: a1, a0
    #|  a2 = move.i64 a0           # live in: a1, a0
    #|  a0 = add.i32 a2, a1        # live in: a2, a1
    #|  a2 = sub.i32 a2, a1        # live in: a0, a2, a1
    #|  a1 = mul.i32 a0, a2        # live in: a0, a2
    #|  a0 = div.i32 a0, a2        # live in: a1, a0, a2
    #|  a0 = rem.i32 a1, a0        # live in: a1, a0
    #|  ret
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
test "Cond Branch Insts Register Allocation" {
  let code =
    #|fn foo(a: Int, b: Int, c: Bool) -> Int{
    #|  if c {
    #|    let x = a + b
    #|    let y = a - b
    #|    x * y
    #|  } else {
    #|    let x = a * b
    #|    let y = a / b
    #|    x - y
    #|  }
    #|}
  let llvm_mod = @TinyMoonBit.compile(code)

  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("foo").unwrap()
  // Live Analysis
  mir_func.alloc_register()
  let expected =
    #|func foo(a0, a1, a2) {
    #|entry:                              ; live in: a0, a1, a2
    #|  t5 = move.i64 0                   # live in: a0, a1, a2
    #|  bne a2, t5, foo_L1, foo_L2        # live in: a0, a1, a2, t5
    #|
    #|; preds: entry
    #|foo_L1:                      ; live in: a0, a1
    #|  a2 = add.i32 a0, a1        # live in: a0, a1
    #|  a0 = sub.i32 a0, a1        # live in: a2, a0, a1
    #|  a0 = mul.i32 a2, a0        # live in: a2, a0
    #|  jmp foo_L3
    #|
    #|; preds: entry
    #|foo_L2:                      ; live in: a0, a1
    #|  a2 = mul.i32 a0, a1        # live in: a0, a1
    #|  a0 = div.i32 a0, a1        # live in: a2, a0, a1
    #|  a0 = sub.i32 a2, a0        # live in: a2, a0
    #|  jmp foo_L3
    #|
    #|; preds: foo_L1, foo_L2
    #|foo_L3:
    #|  ret
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
test "Register Allocation Spill" {
  let code =
    #|fn add12(a1: Int, a2: Int, a3: Int, a4: Int,
    #|         a5: Int, a6: Int, a7: Int, a8: Int,
    #|         a9: Int, b1: Int, b2: Int, b3: Int) -> Int {
    #|  let x1 = a1 + b1;
    #|  let x2 = a1 + b2;
    #|  let x3 = a1 + b3;
    #|  let x4 = a2 + b1;
    #|  let x5 = a2 + b2;
    #|  let x6 = a2 + b3;
    #|  let x7 = a3 + b1;
    #|  let x8 = a3 + b2;
    #|  let x9 = a3 + b3;
    #|  let y1 = a4 + b1;
    #|  let y2 = a4 + b2;
    #|  let y3 = a4 + b3;
    #|  let y4 = a5 + b1;
    #|  let y5 = a5 + b2;
    #|  let y6 = a5 + b3;
    #|  let y7 = a6 + b1;
    #|  let y8 = a6 + b2;
    #|  let y9 = a6 + b3;
    #|  let z1 = a7 + b1;
    #|  let z2 = a7 + b2;
    #|  let z3 = a7 + b3;
    #|  let z4 = a8 + b1;
    #|  let z5 = a8 + b2;
    #|  let z6 = a8 + b3;
    #|  let z7 = a9 + b1;
    #|  let z8 = a9 + b2;
    #|  let z9 = a9 + b3;
    #|  let xr = x1 + x2 + x3;
    #|  let xr = xr + x4 + x5;
    #|  let xr = xr + x6 + x7;
    #|  let xr = xr + x8 + x9;
    #|  let yr = y1 + y2 + y3;
    #|  let yr = yr + y4 + y5;
    #|  let yr = yr + y6 + y7;
    #|  let yr = yr + y8 + y9;
    #|  let zr = z1 + z2 + z3;
    #|  let zr = zr + z4 + z5;
    #|  let zr = zr + z6 + z7;
    #|  let zr = zr + z8 + z9;
    #|  xr + yr + zr
    #|}
  let llvm_mod = @TinyMoonBit.compile(code)
  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  mir_mod.legalize()
  let mir_func = mir_mod.get_function("add12").unwrap()
  // Live Analysis
  mir_func.alloc_register()
  assert_false(mir_func.contains_virtual_reg())
}
