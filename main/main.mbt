///|
fn main {
  try {
    // Debug the mixed types test
    let ctx = @IR.Context::new()
    let mod = ctx.addModule("demo")
    let i32ty = ctx.getInt32Ty()
    let f64ty = ctx.getDoubleTy()
    let fty = ctx.getFunctionType(f64ty, [i32ty, f64ty, i32ty])
    let func = mod.addFunction(fty, "mixed")
    let bb = func.addBasicBlock(name="entry")
    let builder = ctx.createBuilder()
    builder.setInsertPoint(bb)
    let a = func.getArg(0).unwrap()
    let b = func.getArg(1).unwrap()
    let c = func.getArg(2).unwrap()
    let a_double = builder.createSIToFP(a, f64ty)
    let c_double = builder.createSIToFP(c, f64ty)
    let sum1 = builder.createFAdd(a_double, b)
    let sum2 = builder.createFAdd(sum1, c_double)
    let _ = builder.createRet(sum2)
    let mir_func = @GMIR.Function::from_llvm_function(func)
    println("=== Before RegAlloc ===")
    println(mir_func)
    let vm = @GMIR.VirtualMachine::new()
    let result_before = vm.eval_function(mir_func, [
      @GMIR.VMValue::Int(10L),
      @GMIR.VMValue::Double(5.5),
      @GMIR.VMValue::Int(15L),
    ])
    println("Result before regalloc: \{result_before}")
    println("Expected: 10.0 + 5.5 + 15.0 = 30.5")
    let regalloced = @GMIR.reg_alloc_for_function(
      mir_func,
      max_num_reg=17,
      max_num_freg=17,
    )
    println("\n=== After RegAlloc ===")
    println(regalloced)
    let result_after = vm.eval_function(regalloced, [
      @GMIR.VMValue::Int(10L),
      @GMIR.VMValue::Double(5.5),
      @GMIR.VMValue::Int(15L),
    ])
    println("Result after regalloc: \{result_after}")
  } catch {
    e => println("Error: \{e}")
  }
}
