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
  let mir_func = @GMIR.Function::from_llvm_function(func, rv64_config)
  mir_func.alloc_register()
  let expected =
    #|func fadd(%f0, %f1) {
    #|entry:
    #|  %f0 = FAddD %f0, %f1
    #|  Ret %f0
    #|}
    #|
  inspect(mir_func, content=expected)
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
  let mir_func = @GMIR.Function::from_llvm_function(func, rv64_config)
  mir_func.alloc_register()
  inspect(
    mir_func,
    content=(
      #|func mixed(%r0, %f0, %r1) {
      #|entry:
      #|  %f1 = SIToFP(32, 64) %r0
      #|  %f2 = SIToFP(32, 64) %r1
      #|  %f0 = FAddD %f1, %f0
      #|  %f0 = FAddD %f0, %f2
      #|  Ret %f0
      #|}
      #|
    ),
  )
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
  let mir_func = @GMIR.Function::from_llvm_function(func, rv64_config)
  mir_func.alloc_register()
  inspect(
    mir_func,
    content=(
      #|func many_params(%r0, %r1, %r2, %r3, %r4) {
      #|entry:
      #|  %r0 = Addl %r0, %r1
      #|  %r1 = Mull %r2, %r3
      #|  %r1 = Divl %r1, %r4
      #|  %r0 = Subl %r0, %r1
      #|  Ret %r0
      #|}
      #|
    ),
  )
}
