///|
test "Simple Insts RiscV" {
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
  mir_mod.legalize()
  mir_mod.alloc_register()
  mir_mod.post_ra()
  let rvasm = @riscv.mir_module_to_riscv(mir_mod)
  let rvasm = rvasm.map(a => a.to_string()).join("\n")
  println(rvasm)
  let expected = 
    #|foo:
    #|    addw a2, a0, a1
    #|    subw a1, a0, a1
    #|    mulw a0, a2, a1
    #|    divw a1, a2, a1
    #|    remw a0, a0, a1
    #|    ret

  inspect(rvasm, content = expected)
}

