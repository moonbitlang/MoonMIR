
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
  mir_mod.live_analysis()
  let mir_func = mir_mod.get_function("foo").unwrap()

  let expected = 
    #|func foo(a0, a1) {
    #|# live: a0, a1
    #|entry:
    #|  v0 = add.i32 a0, a1         # live in: a0, a1
    #|  v1 = sub.i32 a0, a1         # live in: v0, a0, a1
    #|  v2 = mul.i32 v0, v1         # live in: v0, v1
    #|  v3 = div.i32 v0, v1         # live in: v2, v0, v1
    #|  v4 = rem.i32 v2, v3         # live in: v2, v3
    #|  a0 = move.i64 v4            # live in: v4
    #|  ret
    #|}
    #|

  inspect(mir_func, content=expected)
}

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
  mir_mod.live_analysis()
  let mir_func = mir_mod.get_function("foo").unwrap()

  let expected =
    #|func foo(a0, a1, a2) {
    #|# live: a0, a1, a2
    #|entry:
    #|  bne a2, 0, foo_L1, foo_L2         # live in: a0, a1, a2
    #|
    #|# live: a0, a1
    #|foo_L1:                       ; preds: entry
    #|  v0 = add.i32 a0, a1         # live in: a0, a1
    #|  v2 = move.i32 v0            # live in: v0
    #|  jmp foo_L3                  # live in: v2
    #|
    #|# live: a0, a1
    #|foo_L2:                       ; preds: entry
    #|  v1 = mul.i32 a0, a1         # live in: a0, a1
    #|  v2 = move.i32 v1            # live in: v1
    #|  jmp foo_L3                  # live in: v2
    #|
    #|# live: v2
    #|foo_L3:                       ; preds: foo_L1, foo_L2
    #|  a0 = move.i64 v2         # live in: v2
    #|  ret
    #|}
    #|

  inspect(mir_func, content=expected)
}
