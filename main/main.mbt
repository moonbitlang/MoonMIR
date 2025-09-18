///|
fn main_err() -> Unit raise {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty])
  let fval = mod.addFunction(fty, "fib_iter")
  let entry_bb = fval.addBasicBlock(name="entry")
  let base_case_bb = fval.addBasicBlock(name="base_case")
  let iter_setup_bb = fval.addBasicBlock(name="iter_setup")
  let loop_bb = fval.addBasicBlock(name="loop")
  let loop_body_bb = fval.addBasicBlock(name="loop_body")
  let loop_end_bb = fval.addBasicBlock(name="loop_end")
  let return_bb = fval.addBasicBlock(name="return")
  let builder = ctx.createBuilder()

  // Entry: check if n <= 1
  builder.setInsertPoint(entry_bb)
  let n = fval.getArg(0).unwrap()
  let one = ctx.getConstInt32(1)
  let cond = builder.createICmpSLE(n, one)
  let _ = builder.createCondBr(cond, base_case_bb, iter_setup_bb)

  // Base case: return n
  builder.setInsertPoint(base_case_bb)
  let _ = builder.createRet(n)

  // Setup iteration: a = 0, b = 1, i = 2
  builder.setInsertPoint(iter_setup_bb)
  let _ = builder.createBr(loop_bb)

  // Loop header: check i <= n
  builder.setInsertPoint(loop_bb)
  let i_phi = builder.createPHI(i32ty)
  let a_phi = builder.createPHI(i32ty)
  let b_phi = builder.createPHI(i32ty)
  let two = ctx.getConstInt32(2)
  let zero = ctx.getConstInt32(0)
  i_phi.addIncoming(two, iter_setup_bb)
  a_phi.addIncoming(zero, iter_setup_bb)
  b_phi.addIncoming(one, iter_setup_bb)
  let loop_cond = builder.createICmpSLE(i_phi, n)
  let _ = builder.createCondBr(loop_cond, loop_body_bb, return_bb)

  // Loop body: temp = a + b; a = b; b = temp; i++
  builder.setInsertPoint(loop_body_bb)
  let temp = builder.createAdd(a_phi, b_phi)
  let new_i = builder.createAdd(i_phi, one)
  let _ = builder.createBr(loop_end_bb)

  // Loop end: update phi values
  builder.setInsertPoint(loop_end_bb)
  let _ = builder.createBr(loop_bb)
  i_phi.addIncoming(new_i, loop_end_bb)
  a_phi.addIncoming(b_phi, loop_end_bb)
  b_phi.addIncoming(temp, loop_end_bb)

  // Return b
  builder.setInsertPoint(return_bb)
  let _ = builder.createRet(b_phi)

  // Convert to MIR and execute
  println("Converting LLVM function to MIR...")
  let mir_func = @GMIR.Function::from_llvm_function(fval)
  println("MIR function created successfully:")
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