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
    #|entry:                       ; live in: a0, a1
    #|  a2 = add.i32 a0, a1        # live in: a0, a1
    #|  a1 = sub.i32 a0, a1        # live in: a2, a0, a1
    #|  a0 = mul.i32 a2, a1        # live in: a2, a1
    #|  a1 = div.i32 a2, a1        # live in: a0, a2, a1
    #|  a0 = rem.i32 a0, a1        # live in: a0, a1
    #|  ret
    #|}
    #|
  inspect(mir_func, content=expected)
}

