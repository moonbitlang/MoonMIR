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
//test "Simple IR RegAlloc - add" {
//  let ctx = @IR.Context::new()
//  let mod = ctx.addModule("demo")
//  let i32ty = ctx.getInt32Ty()
//
//  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
//  let func = mod.addFunction(fty, "arith")
//  let bb = func.addBasicBlock(name="entry")
//  let builder = ctx.createBuilder()
//  builder.setInsertPoint(bb)
//
//  let a = func.getArg(0).unwrap()
//  let b = func.getArg(1).unwrap()
//  let r1 = builder.createAdd(a, b)
//  let r2 = builder.createSub(a, b)
//  let r3 = builder.createMul(a, b)
//  let r4 = builder.createSDiv(a, b)
//
//  let r5 = builder.createAdd(r1, r2)
//  let r6 = builder.createSub(r3, r4)
//  let r7 = builder.createMul(r5, r6)
//  let _ = builder.createRet(r7)
//
//  let mir_func = @GMIR.Function::from_llvm_function(func)
//
//  let mir_func = @GMIR.legalize_func(mir_func)
//
//  let before_regalloc_value = run_mir_function(
//    mir_func,
//    [@GMIR.VMValue::Int(10), @GMIR.VMValue::Int(5)]
//  )
//  @GMIR.reg_alloc_for_function(mir_func, max_num_reg=17, max_num_freg=17)
//  let after_regalloc_value = run_mir_function(
//    mir_func,
//    [@GMIR.VMValue::Int(10), @GMIR.VMValue::Int(5)]
//  )
//  //println(mir_func)
//  assert_eq(before_regalloc_value, after_regalloc_value)
//}
