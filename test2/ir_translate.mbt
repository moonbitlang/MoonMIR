
test "Simple Add Function" {

  let code = 
    #|fn add2(x: Int, y: Int) -> Int {
    #|  x + y  
    #|}

  let llvm_mod = @TinyMoonBit.compile(code)

  println(llvm_mod)

  let mod = @MoonMIR.Module::new(@MoonMIR.ArchConfig::riscv64(), source_file="testing")
  mod.translate_llvm_module(llvm_mod)

  println(mod)
}
