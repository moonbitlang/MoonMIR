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
    #|entry:                       ; live in: a0, a1
    #|  v0 = add.i32 a0, a1        # live in: a0, a1
    #|  v1 = sub.i32 a0, a1        # live in: v0, a0, a1
    #|  v2 = mul.i32 v0, v1        # live in: v0, v1
    #|  v3 = div.i32 v0, v1        # live in: v2, v0, v1
    #|  v4 = rem.i32 v2, v3        # live in: v2, v3
    #|  a0 = move.i64 v4           # live in: v4
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
    #|entry:                             ; live in: a0, a1, a2
    #|  bne a2, 0, foo_L1, foo_L2        # live in: a0, a1, a2
    #|
    #|; preds: entry
    #|foo_L1:                      ; live in: a0, a1
    #|  v0 = add.i32 a0, a1        # live in: a0, a1
    #|  v2 = move.i32 v0           # live in: v0
    #|  jmp foo_L3                 # live in: v2
    #|
    #|; preds: entry
    #|foo_L2:                      ; live in: a0, a1
    #|  v1 = mul.i32 a0, a1        # live in: a0, a1
    #|  v2 = move.i32 v1           # live in: v1
    #|  jmp foo_L3                 # live in: v2
    #|
    #|; preds: foo_L1, foo_L2
    #|foo_L3:                   ; live in: v2
    #|  a0 = move.i64 v2        # live in: v2
    #|  ret
    #|}
    #|
  inspect(mir_func, content=expected)
}

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
    #|entry:                           ; live in: a0
    #|  v8 = move.i32 0                # live in: a0
    #|  store.i32 (fp' - 4), v8        # live in: a0, v8
    #|  v9 = move.i32 1                # live in: a0
    #|  store.i32 (fp' - 8), v9        # live in: a0, v9
    #|  jmp sum_to_n_L1                # live in: a0
    #|
    #|; preds: entry, sum_to_n_L2
    #|sum_to_n_L1:                                  ; live in: a0
    #|  v0 = load.i32 (fp' - 8)                     # live in: a0
    #|  ble v0, a0, sum_to_n_L2, sum_to_n_L3        # live in: v0, a0
    #|
    #|; preds: sum_to_n_L1
    #|sum_to_n_L2:                     ; live in: a0
    #|  v2 = load.i32 (fp' - 4)        # live in: a0
    #|  v3 = load.i32 (fp' - 8)        # live in: a0, v2
    #|  v4 = add.i32 v2, v3            # live in: a0, v2, v3
    #|  store.i32 (fp' - 4), v4        # live in: a0, v4
    #|  v5 = load.i32 (fp' - 8)        # live in: a0
    #|  v6 = add.i32 v5, 1             # live in: a0, v5
    #|  store.i32 (fp' - 8), v6        # live in: a0, v6
    #|  jmp sum_to_n_L1                # live in: a0
    #|
    #|; preds: sum_to_n_L1
    #|sum_to_n_L3:
    #|  v7 = load.i32 (fp' - 4)
    #|  a0 = move.i64 v7               # live in: v7
    #|  ret
    #|}

  inspect(mir_func, content=expected)
}
