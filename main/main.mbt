///|
fn main_err() -> Unit raise {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty])
  let fval = mod.addFunction(fty, "bool_constants")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let x = fval.getArg(0).unwrap()
  let zero = ctx.getConstInt32(0)
  let one = ctx.getConstInt32(1)
  let cond = builder.createICmpEQ(x, zero)
  let result = builder.createSelect(cond, one, zero)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval)
  println(mir_func)
}

///|
fn main {
  main_err() catch {
    e => {
      println("Error: \{e}")
      return
    }
  }
}
