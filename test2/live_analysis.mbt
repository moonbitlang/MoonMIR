
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
  let mir_func = mir_mod.functions[0]
  println(mir_func)

  let expected = 
    #|func foo(a0, a1) {
    #|# live: a0, a1
    #|entry:
    #|  v0 = add.i32 a0, a1     # live in: a0, a1
    #|  v1 = sub.i32 a0, a1     # live in: a0, a1
    #|  v2 = mul.i32 v0, v1     # live in: v0, v1
    #|  v3 = div.i32 v0, v1     # live in: v0, v1
    #|  v4 = rem.i32 v2, v3     # live in: v2, v3
    #|  ret v4                  # live in: v4
    #|}
    #|

  inspect(mir_func, content=expected)
}
