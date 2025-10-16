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
  let expetced =
    #|.global foo
    #|foo:
    #|    mv a2, a0
    #|    addw a0, a2, a1
    #|    subw a2, a2, a1
    #|    mulw a1, a0, a2
    #|    divw a0, a0, a2
    #|    remw a0, a1, a0
    #|    ret
  inspect(rvasm, content=expetced)
}

//test "Simple Call" {
//  let code = 
//    #|extern "C" fn plus1(x: Int) -> Int = "print_int";
//    #|
//    #|fn print2_num(a: Int, b: Int) -> Unit {
//    #|  let _ = plus1(a);
//    #|  let b = a + b;
//    #|  let _ = plus1(b);
//    #|}
//  let llvm_mod = @TinyMoonBit.compile(code)
//  // IRTranslate
//  let mir_mod = Module::new(rv64)
//  mir_mod.translate_llvm_module(llvm_mod)
//  println(mir_mod)
//  mir_mod.legalize()
//  println(mir_mod)
//  mir_mod.alloc_register()
//  println(mir_mod)
//  mir_mod.post_ra()
//  println(mir_mod)
//  let rvasm = @riscv.mir_module_to_riscv(mir_mod)
//  let rvasm = rvasm.map(a => a.to_string()).join("\n")
//  println(rvasm)
//}
