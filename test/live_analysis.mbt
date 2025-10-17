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
  // Live Analysis
  mir_func.live_analysis()
  let expected =
    #|func foo(a0, a1) {
    #|entry:                       ; live in: a1, a0
    #|  v0 = move.i64 a0           # live in: a1, a0
    #|  v1 = move.i64 a1           # live in: v0, a1
    #|  v2 = add.i32 v0, v1        # live in: v0, v1
    #|  v3 = sub.i32 v0, v1        # live in: v2, v0, v1
    #|  v4 = mul.i32 v2, v3        # live in: v2, v3
    #|  v5 = div.i32 v2, v3        # live in: v4, v2, v3
    #|  v6 = rem.i32 v4, v5        # live in: v4, v5
    #|  a0 = move.i64 v6           # live in: v6
    #|  ret
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
test "Cond Branch Insts Live Analysis" {
  let code =
    #|fn foo(a: Int, b: Int, c: Bool) -> Int{
    #|  if c {
    #|    a + b
    #|  } else {
    #|    a * b
    #|  }
    #|}
  let llvm_mod = @TinyMoonBit.compile(code)

  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("foo").unwrap()
  // Live Analysis
  mir_func.live_analysis()
  let expected =
    #|func foo(a0, a1, a2) {
    #|entry:                             ; live in: a2, a1, a0
    #|  v0 = move.i64 a0                 # live in: a2, a1, a0
    #|  v1 = move.i64 a1                 # live in: v0, a2, a1
    #|  v2 = move.i64 a2                 # live in: v0, v1, a2
    #|  bne v2, 0, foo_L1, foo_L2        # live in: v0, v1, v2
    #|
    #|; preds: entry
    #|foo_L1:                      ; live in: v0, v1
    #|  v3 = add.i32 v0, v1        # live in: v0, v1
    #|  v5 = move.i32 v3           # live in: v3
    #|  jmp foo_L3                 # live in: v5
    #|
    #|; preds: entry
    #|foo_L2:                      ; live in: v0, v1
    #|  v4 = mul.i32 v0, v1        # live in: v0, v1
    #|  v5 = move.i32 v4           # live in: v4
    #|  jmp foo_L3                 # live in: v5
    #|
    #|; preds: foo_L1, foo_L2
    #|foo_L3:                   ; live in: v5
    #|  a0 = move.i64 v5        # live in: v5
    #|  ret
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
test "While Live Analysis" {
  let code =
    #|fn sum_to_n(n: Int) -> Int {
    #|  let mut sum = 0;
    #|  let mut i = 1;
    #|  while i <= n {
    #|    sum = sum + i;
    #|    i = i + 1;
    #|  }
    #|  sum
    #|}
  let llvm_mod = @TinyMoonBit.compile(code)
  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("sum_to_n").unwrap()
  // Live Analysis
  mir_func.live_analysis()
  let expected =
    #|func sum_to_n(a0) {
    #|entry:                            ; live in: fp', a0
    #|  v0 = move.i64 a0                # live in: fp', a0
    #|  v9 = move.i32 0                 # live in: fp', v0
    #|  store.i32 (fp' - 4), v9         # live in: fp', v0, v9
    #|  v10 = move.i32 1                # live in: fp', v0
    #|  store.i32 (fp' - 8), v10        # live in: fp', v0, v10
    #|  jmp sum_to_n_L1                 # live in: fp', v0
    #|
    #|; preds: entry, sum_to_n_L2
    #|sum_to_n_L1:                                  ; live in: fp', v0
    #|  v1 = load.i32 (fp' - 8)                     # live in: fp', v0
    #|  ble v1, v0, sum_to_n_L2, sum_to_n_L3        # live in: fp', v1, v0
    #|
    #|; preds: sum_to_n_L1
    #|sum_to_n_L2:                     ; live in: fp', v0
    #|  v3 = load.i32 (fp' - 4)        # live in: fp', v0
    #|  v4 = load.i32 (fp' - 8)        # live in: fp', v0, v3
    #|  v5 = add.i32 v3, v4            # live in: fp', v0, v3, v4
    #|  store.i32 (fp' - 4), v5        # live in: fp', v0, v5
    #|  v6 = load.i32 (fp' - 8)        # live in: fp', v0
    #|  v7 = add.i32 v6, 1             # live in: fp', v0, v6
    #|  store.i32 (fp' - 8), v7        # live in: fp', v0, v7
    #|  jmp sum_to_n_L1                # live in: fp', v0
    #|
    #|; preds: sum_to_n_L1
    #|sum_to_n_L3:                     ; live in: fp'
    #|  v8 = load.i32 (fp' - 4)        # live in: fp'
    #|  a0 = move.i64 v8               # live in: v8
    #|  ret
    #|}
    #|
  inspect(mir_func, content=expected)
}
