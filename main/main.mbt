fn llvm_add() -> @IR.Module raise {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let func = mod.addFunction(fty, "add")
  let bb = func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = func.getArg(0).unwrap()
  let b = func.getArg(1).unwrap()
  let res = builder.createAdd(a, b)
  let _ = builder.createRet(res)
  return mod
}

fn rv_cvt(llvm_module: () -> @IR.Module raise?) -> Unit raise {
  let mod = llvm_module()
  println("==================== LLVM IR ================")
  mod.dump()
  println("==================== GMIR ================")
  let gmir = @GMIR.Module::from_llvm_module(mod)
  println(gmir)
  println("==================== GMIR Legalized ================")
  let gmir = gmir.legalize()
  println(gmir)
  println("==================== GMIR RegAlloc ================")
  let gmir = gmir.reg_alloc(max_num_reg = 17, max_num_freg = 17)
  println(gmir)
  println("==================== GMIR PostRA ================")
  let gmir = gmir.post_ra()
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
  rv_cvt(llvm_add) catch {
    e => println(e)
  }
}
