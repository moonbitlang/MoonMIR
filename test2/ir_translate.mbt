
test "Simple Add Function" {
  let ctx = @IR.Context::new()
  let llvm_mod = ctx.addModule("demo")
  let builder = ctx.createBuilder()

  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])

  let fval = llvm_mod.addFunction(fty, "add2")
  let entry = fval.addBasicBlock(name="entry")

  builder.setInsertPoint(entry)

  let arg0 = fval.getArg(0).unwrap()
  let arg1 = fval.getArg(1).unwrap()

  let res = builder.createAdd(arg0, arg1)
  let _ = builder.createRet(res)


  println(llvm_mod)

  let mod = @MoonMIR.Module::new(@MoonMIR.ArchConfig::riscv64(), source_file="testing")
  mod.translate_llvm_module(llvm_mod)

  println(mod)

  //let func = mod.functions.get(0).unwrap()
  //
  //println(func)

}
