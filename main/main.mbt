///|
fn main_err() -> Unit raise {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [])
  let func = mod.addFunction(fty, "ret42")
  let bb = func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let forty_two = ctx.getConstInt32(42)
  let _ = builder.createRet(forty_two)
  println("==================== LLVM IR ================")
  mod.dump()
  println("==================== GMIR ================")
  let gmir = @GMIR.Module::from_llvm_module(mod)
  println(gmir)
  println("==================== GMIR Legalized ================")
  let gmir = gmir.legalize()
  println(gmir)
  println("==================== RISCV ================")
  let riscv_asm = @riscv.from_gmir_module(gmir)
  fn print_asm(inst : @riscv.RvAsm) {
    match inst {
      Label(_) as l => println(l)
      inst => println("  \{inst}")
    }
  }

  riscv_asm.each(line => print_asm(line))
}

///|
fn main {
  main_err() catch {
    e => println(e)
  }
}
