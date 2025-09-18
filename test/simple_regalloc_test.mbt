///|
///
/// int arith(int a, int b) {
///   int r1 = a + b;
///   int r2 = a - b;
///   int r3 = a * b;
///   int r4 = a / b;
///
///   int r5 = r1 + r2;
///   int r6 = r3 - r4;
///   int r7 = r5 * r6;
///   return r7;
/// }

///|
/// Test: Simple function with floating point parameters
/// double fadd(double a, double b) { return a + b; }
test "Simple IR RegAlloc - fadd" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f64ty = ctx.getDoubleTy()
  let fty = ctx.getFunctionType(f64ty, [f64ty, f64ty])
  let func = mod.addFunction(fty, "fadd")
  let bb = func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = func.getArg(0).unwrap()
  let b = func.getArg(1).unwrap()
  let sum = builder.createFAdd(a, b)
  let _ = builder.createRet(sum)
  let mir_func = @GMIR.Function::from_llvm_function(func)
  let before_regalloc_value = run_mir_function(mir_func, [
    @GMIR.VMValue::Double(3.14),
    @GMIR.VMValue::Double(2.86),
  ])
  let regalloced = @GMIR.reg_alloc_for_function(
    mir_func,
    max_num_reg=17,
    max_num_freg=17,
  )
  let after_regalloc_value = run_mir_function(regalloced, [
    @GMIR.VMValue::Double(3.14),
    @GMIR.VMValue::Double(2.86),
  ])
  assert_eq(before_regalloc_value, after_regalloc_value)
}

///|
/// Test: Mixed integer and floating point parameters
/// double mixed(int a, double b, int c) { return (double)a + b + (double)c; }
test "Simple IR RegAlloc - mixed types" {
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
  let before_regalloc_value = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(10L),
    @GMIR.VMValue::Double(5.5),
    @GMIR.VMValue::Int(15L),
  ])
  let regalloced = @GMIR.reg_alloc_for_function(
    mir_func,
    max_num_reg=17,
    max_num_freg=17,
  )
  let after_regalloc_value = run_mir_function(regalloced, [
    @GMIR.VMValue::Int(10L),
    @GMIR.VMValue::Double(5.5),
    @GMIR.VMValue::Int(15L),
  ])
  assert_eq(before_regalloc_value, after_regalloc_value)
}

///|
/// Test: Many parameters to check proper allocation
/// int many_params(int a, int b, int c, int d, int e) { 
///   return a + b - c * d / e; 
/// }
test "Simple IR RegAlloc - many parameters" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty, i32ty, i32ty, i32ty])
  let func = mod.addFunction(fty, "many_params")
  let bb = func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = func.getArg(0).unwrap()
  let b = func.getArg(1).unwrap()
  let c = func.getArg(2).unwrap()
  let d = func.getArg(3).unwrap()
  let e = func.getArg(4).unwrap()
  let sum = builder.createAdd(a, b)
  let mul = builder.createMul(c, d)
  let div = builder.createSDiv(mul, e)
  let result = builder.createSub(sum, div)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(func)
  let before_regalloc_value = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(20L),
    @GMIR.VMValue::Int(10L),
    @GMIR.VMValue::Int(6L),
    @GMIR.VMValue::Int(5L),
    @GMIR.VMValue::Int(3L),
  ])
  let regalloced = @GMIR.reg_alloc_for_function(
    mir_func,
    max_num_reg=17,
    max_num_freg=17,
  )
  let after_regalloc_value = run_mir_function(regalloced, [
    @GMIR.VMValue::Int(20L),
    @GMIR.VMValue::Int(10L),
    @GMIR.VMValue::Int(6L),
    @GMIR.VMValue::Int(5L),
    @GMIR.VMValue::Int(3L),
  ])
  assert_eq(before_regalloc_value, after_regalloc_value)
}

///|
test "Simple IR RegAlloc - add" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let func = mod.addFunction(fty, "arith")
  let bb = func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = func.getArg(0).unwrap()
  let b = func.getArg(1).unwrap()
  let r1 = builder.createAdd(a, b)
  let r2 = builder.createSub(a, b)
  let r3 = builder.createMul(a, b)
  let r4 = builder.createSDiv(a, b)
  let r5 = builder.createAdd(r1, r2)
  let r6 = builder.createSub(r3, r4)
  let r7 = builder.createMul(r5, r6)
  let _ = builder.createRet(r7)
  let mir_func = @GMIR.Function::from_llvm_function(func)
  let config = @GMIR.LegalizeConfig::{
    max_num_call_regs: 8,
    max_num_call_fregs: 8
  }
  let legalized = @GMIR.legalize_func(mir_func, config)
  let before_regalloc_value = run_mir_function(legalized, [
    @GMIR.VMValue::Int(10),
    @GMIR.VMValue::Int(5),
  ])
  let regalloced = @GMIR.reg_alloc_for_function(
    mir_func,
    max_num_reg=17,
    max_num_freg=17,
  )
  let after_regalloc_value = run_mir_function(regalloced, [
    @GMIR.VMValue::Int(10),
    @GMIR.VMValue::Int(5),
  ])
  assert_eq(before_regalloc_value, after_regalloc_value)
}
