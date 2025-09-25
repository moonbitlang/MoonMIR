///|
let rv64_config : @GMIR.ArchConfig = @GMIR.ArchConfig::riscv64()

///|
/// int ret42() { retun 42; }
test "Simple IRTranslate - ret42" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()

  // ret42
  let fty = ctx.getFunctionType(i32ty, [])
  let fourty_two = ctx.getConstInt32(42)
  let fval = mod.addFunction(fty, "ret42")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let _ = builder.createRet(fourty_two)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func ret42() {
    #|entry:
    #|  Ret 42
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// float fadd(float a, float b) { return a + b; }
test "Simple IRTranslate - fadd" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f32ty = ctx.getFloatTy()
  let fty = ctx.getFunctionType(f32ty, [f32ty, f32ty])
  let fval = mod.addFunction(fty, "fadd")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let sum = builder.createFAdd(a, b)
  let _ = builder.createRet(sum)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func fadd(%vf0, %vf1) {
    #|entry:
    #|  %vf2 = FAddS %vf0, %vf1
    #|  Ret %vf2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// double dadd(double a, double b) { return a + b; }
test "Simple IRTranslate - dadd" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f64ty = ctx.getDoubleTy()
  let fty = ctx.getFunctionType(f64ty, [f64ty, f64ty])
  let fval = mod.addFunction(fty, "dadd")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let sum = builder.createFAdd(a, b)
  let _ = builder.createRet(sum)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func dadd(%vf0, %vf1) {
    #|entry:
    #|  %vf2 = FAddD %vf0, %vf1
    #|  Ret %vf2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// float fsub(float a, float b) { return a - b; }
test "Simple IRTranslate - fsub" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f32ty = ctx.getFloatTy()
  let fty = ctx.getFunctionType(f32ty, [f32ty, f32ty])
  let fval = mod.addFunction(fty, "fsub")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let result = builder.createFSub(a, b)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func fsub(%vf0, %vf1) {
    #|entry:
    #|  %vf2 = FSubS %vf0, %vf1
    #|  Ret %vf2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// float fmul(float a, float b) { return a * b; }
test "Simple IRTranslate - fmul" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f32ty = ctx.getFloatTy()
  let fty = ctx.getFunctionType(f32ty, [f32ty, f32ty])
  let fval = mod.addFunction(fty, "fmul")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let result = builder.createFMul(a, b)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func fmul(%vf0, %vf1) {
    #|entry:
    #|  %vf2 = FMulS %vf0, %vf1
    #|  Ret %vf2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// float fdiv(float a, float b) { return a / b; }
test "Simple IRTranslate - fdiv" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f32ty = ctx.getFloatTy()
  let fty = ctx.getFunctionType(f32ty, [f32ty, f32ty])
  let fval = mod.addFunction(fty, "fdiv")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let result = builder.createFDiv(a, b)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func fdiv(%vf0, %vf1) {
    #|entry:
    #|  %vf2 = FDivS %vf0, %vf1
    #|  Ret %vf2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int fcmp_eq(float a, float b) { return a == b; }
test "Simple IRTranslate - fcmp eq" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f32ty = ctx.getFloatTy()
  let i1ty = ctx.getInt1Ty()
  let fty = ctx.getFunctionType(i1ty, [f32ty, f32ty])
  let fval = mod.addFunction(fty, "fcmp_eq")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let result = builder.createFCmpOEQ(a, b)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func fcmp_eq(%vf0, %vf1) {
    #|entry:
    #|  %v0 = FeqS %vf0, %vf1
    #|  Ret %v0
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
///
/// int add(int a, int b) { return a + b; }
test "Simple IRTranslate - add" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()

  // add
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "add")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let sum = builder.createAdd(a, b)
  let _ = builder.createRet(sum)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func add(%v0, %v1) {
    #|entry:
    #|  %v2 = Addl %v0, %v1
    #|  Ret %v2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
///
/// int icmp(int a, int b) { return a == b; }
test "Simple IRTranslate - icmp" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let boolty = ctx.getInt1Ty()

  // icmp
  let fty = ctx.getFunctionType(boolty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "icmp")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let cmp = builder.createICmpEQ(a, b)
  let _ = builder.createRet(cmp)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func icmp(%v0, %v1) {
    #|entry:
    #|  %v2 = Eq %v0, %v1
    #|  Ret %v2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int cond_branch(int a, int b, int v1, int v2) {
///   if (a > b) { return v1; }
///   return v2;
/// }
test "Simple IRTranslate - cond branch" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()

  // cond_branch
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty, i32ty, i32ty])
  let fval = mod.addFunction(fty, "cond_branch")
  let entry_bb = fval.addBasicBlock(name="entry")
  let then_bb = fval.addBasicBlock(name="then")
  let else_bb = fval.addBasicBlock(name="else")
  let merge_bb = fval.addBasicBlock(name="merge")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(entry_bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let v1 = fval.getArg(2).unwrap()
  let v2 = fval.getArg(3).unwrap()
  let cmp = builder.createICmpSGT(a, b)
  let _ = builder.createCondBr(cmp, then_bb, else_bb)
  builder.setInsertPoint(then_bb)
  let _ = builder.createBr(merge_bb)
  builder.setInsertPoint(else_bb)
  let _ = builder.createBr(merge_bb)
  builder.setInsertPoint(merge_bb)
  let phi = builder.createPHI(i32ty)
  phi.addIncoming(v1, then_bb)
  phi.addIncoming(v2, else_bb)
  let _ = builder.createRet(phi)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func cond_branch(%v0, %v1, %v2, %v3) {
    #|entry:
    #|  Bgt %v0, %v1, then, else
    #|then:                       ; preds: entry
    #|  %v4 = Movq %v2
    #|  Jmp merge
    #|else:                       ; preds: entry
    #|  %v4 = Movq %v3
    #|  Jmp merge
    #|merge:                       ; preds: then, else
    #|  Ret %v4
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int mul(int a, int b) { return a * b; }
test "Simple IRTranslate - mul" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "mul")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let product = builder.createMul(a, b)
  let _ = builder.createRet(product)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func mul(%v0, %v1) {
    #|entry:
    #|  %v2 = Mull %v0, %v1
    #|  Ret %v2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int div(int a, int b) { return a / b; }
test "Simple IRTranslate - div" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "div")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let quotient = builder.createSDiv(a, b)
  let _ = builder.createRet(quotient)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func div(%v0, %v1) {
    #|entry:
    #|  %v2 = Divl %v0, %v1
    #|  Ret %v2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int rem(int a, int b) { return a % b; }
test "Simple IRTranslate - rem" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "rem")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let remainder = builder.createSRem(a, b)
  let _ = builder.createRet(remainder)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func rem(%v0, %v1) {
    #|entry:
    #|  %v2 = Reml %v0, %v1
    #|  Ret %v2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int shl(int a, int b) { return a << b; }
test "Simple IRTranslate - shl" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "shl")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let shifted = builder.createShl(a, b)
  let _ = builder.createRet(shifted)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func shl(%v0, %v1) {
    #|entry:
    #|  %v2 = Shl %v0, %v1
    #|  Ret %v2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int and_op(int a, int b) { return a & b; }
test "Simple IRTranslate - and" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "and_op")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let result = builder.createAnd(a, b)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func and_op(%v0, %v1) {
    #|entry:
    #|  %v2 = And %v0, %v1
    #|  Ret %v2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// short trunc_test(int a) { return (short)a; }
test "Simple IRTranslate - trunc" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let i16ty = ctx.getInt16Ty()
  let fty = ctx.getFunctionType(i16ty, [i32ty])
  let fval = mod.addFunction(fty, "trunc_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let result = builder.createTrunc(a, i16ty)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func trunc_test(%v0) {
      #|entry:
      #|  %v1 = Trunc %v0
      #|  Ret %v1
      #|}
      #|
    ),
  )
}

///|
/// long zext_test(int a) { return (unsigned long)a; }
test "Simple IRTranslate - zext" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let i64ty = ctx.getInt64Ty()
  let fty = ctx.getFunctionType(i64ty, [i32ty])
  let fval = mod.addFunction(fty, "zext_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let result = builder.createZExt(a, i64ty)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func zext_test(%v0) {
      #|entry:
      #|  %v1 = ZExt %v0
      #|  Ret %v1
      #|}
      #|
    ),
  )
}

///|
/// long sext_test(int a) { return (long)a; }
test "Simple IRTranslate - sext" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let i64ty = ctx.getInt64Ty()
  let fty = ctx.getFunctionType(i64ty, [i32ty])
  let fval = mod.addFunction(fty, "sext_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let result = builder.createSExt(a, i64ty)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func sext_test(%v0) {
      #|entry:
      #|  %v1 = SExt %v0
      #|  Ret %v1
      #|}
      #|
    ),
  )
}

///|
/// double fpext_test(float a) { return (double)a; }
test "Simple IRTranslate - fpext" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f32ty = ctx.getFloatTy()
  let f64ty = ctx.getDoubleTy()
  let fty = ctx.getFunctionType(f64ty, [f32ty])
  let fval = mod.addFunction(fty, "fpext_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let result = builder.createFPExt(a, f64ty)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func fpext_test(%vf0) {
      #|entry:
      #|  %vf1 = FPExt %vf0
      #|  Ret %vf1
      #|}
      #|
    ),
  )
}

///|
/// float fptrunc_test(double a) { return (float)a; }
test "Simple IRTranslate - fptrunc" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f32ty = ctx.getFloatTy()
  let f64ty = ctx.getDoubleTy()
  let fty = ctx.getFunctionType(f32ty, [f64ty])
  let fval = mod.addFunction(fty, "fptrunc_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let result = builder.createFPTrunc(a, f32ty)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func fptrunc_test(%vf0) {
      #|entry:
      #|  %vf1 = FPTrunc %vf0
      #|  Ret %vf1
      #|}
      #|
    ),
  )
}

///|
/// int fptosi_test(float a) { return (int)a; }
test "Simple IRTranslate - fptosi" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f32ty = ctx.getFloatTy()
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [f32ty])
  let fval = mod.addFunction(fty, "fptosi_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let result = builder.createFPToSI(a, i32ty)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func fptosi_test(%vf0) {
      #|entry:
      #|  %v0 = FPToSI(32, 32) %vf0
      #|  Ret %v0
      #|}
      #|
    ),
  )
}

///|
/// float sitofp_test(int a) { return (float)a; }
test "Simple IRTranslate - sitofp" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let f32ty = ctx.getFloatTy()
  let fty = ctx.getFunctionType(f32ty, [i32ty])
  let fval = mod.addFunction(fty, "sitofp_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let result = builder.createSIToFP(a, f32ty)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func sitofp_test(%v0) {
    #|entry:
    #|  %vf0 = SIToFP(32, 32) %v0
    #|  Ret %vf0
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int alloca_load_store_test() {
///   int x = 42;
///   return x;
/// }
test "Simple IRTranslate - alloca load store" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [])
  let fval = mod.addFunction(fty, "alloca_load_store_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)

  // alloca for x
  let x_alloca = builder.createAlloca(i32ty)
  let const_42 = ctx.getConstInt32(42)

  // store 42 to x
  let _ = builder.createStore(const_42, x_alloca)

  // load x
  let x_value = builder.createLoad(i32ty, x_alloca)

  // return x
  let _ = builder.createRet(x_value)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func alloca_load_store_test() {
      #|entry:
      #|  Storel (fp' - 4), 42
      #|  %v0 = Loadl (fp' - 4)
      #|  Ret %v0
      #|}
      #|
    ),
  )
}

///|
/// int gep_test(int* arr, int i) { return arr[i]; }
test "Simple IRTranslate - gep array access" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let ptr_ty = ctx.getPtrTy()
  let fty = ctx.getFunctionType(i32ty, [ptr_ty, i32ty])
  let fval = mod.addFunction(fty, "gep_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let arr = fval.getArg(0).unwrap()
  let i = fval.getArg(1).unwrap()

  // GEP to get arr[i]
  let gep = builder.createGEP(arr, i32ty, [i])

  // Load from arr[i]
  let value = builder.createLoad(i32ty, gep)

  // Return value
  let _ = builder.createRet(value)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func gep_test(%v0, %v1) {
    #|entry:
    #|  %v2 = Mulq %v1, 4
    #|  %v3 = Addq %v0, %v2
    #|  %v4 = Loadl %v3
    #|  Ret %v4
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int icmp_ne(int a, int b) { return a != b; }
test "Simple IRTranslate - icmp ne" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let boolty = ctx.getInt1Ty()
  let fty = ctx.getFunctionType(boolty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "icmp_ne")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let cmp = builder.createICmpNE(a, b)
  let _ = builder.createRet(cmp)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func icmp_ne(%v0, %v1) {
    #|entry:
    #|  %v2 = Ne %v0, %v1
    #|  Ret %v2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int icmp_slt(int a, int b) { return a < b; }
test "Simple IRTranslate - icmp slt" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let boolty = ctx.getInt1Ty()
  let fty = ctx.getFunctionType(boolty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "icmp_slt")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let cmp = builder.createICmpSLT(a, b)
  let _ = builder.createRet(cmp)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func icmp_slt(%v0, %v1) {
    #|entry:
    #|  %v2 = Lt %v0, %v1
    #|  Ret %v2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int icmp_ule(int a, int b) { return (unsigned)a <= (unsigned)b; }
test "Simple IRTranslate - icmp ule" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let boolty = ctx.getInt1Ty()
  let fty = ctx.getFunctionType(boolty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "icmp_ule")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let cmp = builder.createICmpULE(a, b)
  let _ = builder.createRet(cmp)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  let expected =
    #|func icmp_ule(%v0, %v1) {
    #|entry:
    #|  %v2 = Le %v0, %v1
    #|  Ret %v2
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
/// int fcmp_one(float a, float b) { return a != b && !isnan(a) && !isnan(b); }
test "Simple IRTranslate - fcmp one" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f32ty = ctx.getFloatTy()
  let i1ty = ctx.getInt1Ty()
  let fty = ctx.getFunctionType(i1ty, [f32ty, f32ty])
  let fval = mod.addFunction(fty, "fcmp_one")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let result = builder.createFCmpONE(a, b)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func fcmp_one(%vf0, %vf1) {
      #|entry:
      #|  %v0 = FneS %vf0, %vf1
      #|  Ret %v0
      #|}
      #|
    ),
  )
}

///|
/// int fcmp_ogt_double(double a, double b) { return a > b; }
test "Simple IRTranslate - fcmp ogt double" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f64ty = ctx.getDoubleTy()
  let i1ty = ctx.getInt1Ty()
  let fty = ctx.getFunctionType(i1ty, [f64ty, f64ty])
  let fval = mod.addFunction(fty, "fcmp_ogt_double")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let result = builder.createFCmpOGT(a, b)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func fcmp_ogt_double(%vf0, %vf1) {
      #|entry:
      #|  %v0 = FgtD %vf0, %vf1
      #|  Ret %v0
      #|}
      #|
    ),
  )
}

///|
/// int select_test(int cond, int a, int b) {
///   return cond ? a : b;
/// }
test "Simple IRTranslate - select" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let i1ty = ctx.getInt1Ty()
  let fty = ctx.getFunctionType(i32ty, [i1ty, i32ty, i32ty])
  let fval = mod.addFunction(fty, "select_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let cond = fval.getArg(0).unwrap()
  let a = fval.getArg(1).unwrap()
  let b = fval.getArg(2).unwrap()
  let result = builder.createSelect(cond, a, b)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func select_test(%v0, %v1, %v2) {
      #|entry:
      #|  %v3 = Select %v0, %v1, %v2
      #|  Ret %v3
      #|}
      #|
    ),
  )
}

///|
/// int simple_phi(int cond, int a, int b) {
///   int result;
///   if (cond) {
///     result = a;
///   } else {
///     result = b;
///   }
///   return result;
/// }
test "Simple IRTranslate - simple phi" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let i1ty = ctx.getInt1Ty()
  let fty = ctx.getFunctionType(i32ty, [i1ty, i32ty, i32ty])
  let fval = mod.addFunction(fty, "simple_phi")
  let entry_bb = fval.addBasicBlock(name="entry")
  let then_bb = fval.addBasicBlock(name="then")
  let else_bb = fval.addBasicBlock(name="else")
  let merge_bb = fval.addBasicBlock(name="merge")
  let builder = ctx.createBuilder()

  // Entry block
  builder.setInsertPoint(entry_bb)
  let cond = fval.getArg(0).unwrap()
  let a = fval.getArg(1).unwrap()
  let b = fval.getArg(2).unwrap()
  let _ = builder.createCondBr(cond, then_bb, else_bb)

  // Then block
  builder.setInsertPoint(then_bb)
  let _ = builder.createBr(merge_bb)

  // Else block
  builder.setInsertPoint(else_bb)
  let _ = builder.createBr(merge_bb)

  // Merge block
  builder.setInsertPoint(merge_bb)
  let result_phi = builder.createPHI(i32ty)
  result_phi.addIncoming(a, then_bb)
  result_phi.addIncoming(b, else_bb)
  let _ = builder.createRet(result_phi)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func simple_phi(%v0, %v1, %v2) {
      #|entry:
      #|  Bne %v0, 0, then, else
      #|then:                       ; preds: entry
      #|  %v3 = Movq %v1
      #|  Jmp merge
      #|else:                       ; preds: entry
      #|  %v3 = Movq %v2
      #|  Jmp merge
      #|merge:                       ; preds: then, else
      #|  Ret %v3
      #|}
      #|
    ),
  )
}

///|
/// Helper function for call tests
/// int helper_add(int a, int b) { return a + b; }
/// int call_with_return(int x, int y) {
///   return helper_add(x, y);
/// }
test "Simple IRTranslate - call with return" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()

  // Create helper function first
  let helper_fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let helper_func = mod.addFunction(helper_fty, "helper_add")
  let helper_bb = helper_func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(helper_bb)
  let a = helper_func.getArg(0).unwrap()
  let b = helper_func.getArg(1).unwrap()
  let sum = builder.createAdd(a, b)
  let _ = builder.createRet(sum)

  // Create caller function
  let caller_fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let caller_func = mod.addFunction(caller_fty, "call_with_return")
  let caller_bb = caller_func.addBasicBlock(name="entry")
  builder.setInsertPoint(caller_bb)
  let x = caller_func.getArg(0).unwrap()
  let y = caller_func.getArg(1).unwrap()
  let result = builder.createCall(helper_func, [x, y])
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(caller_func, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func call_with_return(%v0, %v1) {
      #|entry:
      #|  %v2 = Call helper_add, %v0, %v1
      #|  Ret %v2
      #|}
      #|
    ),
  )
}

///|
/// Helper function for void call tests
/// void print_value(int value) { /* prints value */ }
/// void call_void() {
///   print_value(42);
/// }
test "Simple IRTranslate - call void" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let void_ty = ctx.getVoidTy()

  // Create helper function first
  let helper_fty = ctx.getFunctionType(void_ty, [i32ty])
  let helper_func = mod.addFunction(helper_fty, "print_value")
  let helper_bb = helper_func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(helper_bb)
  let _ = builder.createRetVoid()

  // Create caller function
  let caller_fty = ctx.getFunctionType(void_ty, [])
  let caller_func = mod.addFunction(caller_fty, "call_void")
  let caller_bb = caller_func.addBasicBlock(name="entry")
  builder.setInsertPoint(caller_bb)
  let value = ctx.getConstInt32(42)
  let _ = builder.createCall(helper_func, [value])
  let _ = builder.createRetVoid()
  let mir_func = @GMIR.Function::from_llvm_function(caller_func, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func call_void() {
      #|entry:
      #|  %v0 = Movl 42
      #|  Call print_value, %v0
      #|  Ret 
      #|}
      #|
    ),
  )
}

///|
/// Call with mixed argument types
/// float mixed_call(int i, float f) { return (float)i + f; }
/// float call_mixed(int x) {
///   return mixed_call(x, 3.14);
/// }
test "Simple IRTranslate - call mixed types" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let f32ty = ctx.getFloatTy()

  // Create helper function first
  let helper_fty = ctx.getFunctionType(f32ty, [i32ty, f32ty])
  let helper_func = mod.addFunction(helper_fty, "mixed_call")
  let helper_bb = helper_func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(helper_bb)
  let i = helper_func.getArg(0).unwrap()
  let f = helper_func.getArg(1).unwrap()
  let i_float = builder.createSIToFP(i, f32ty)
  let result = builder.createFAdd(i_float, f)
  let _ = builder.createRet(result)

  // Create caller function
  let caller_fty = ctx.getFunctionType(f32ty, [i32ty])
  let caller_func = mod.addFunction(caller_fty, "call_mixed")
  let caller_bb = caller_func.addBasicBlock(name="entry")
  builder.setInsertPoint(caller_bb)
  let x = caller_func.getArg(0).unwrap()
  let pi = ctx.getConstFloat(3.14)
  let result = builder.createCall(helper_func, [x, pi])
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(caller_func, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func call_mixed(%v0) {
      #|entry:
      #|  %vf0 = FMovS 3.140000104904175
      #|  %vf1 = Call mixed_call, %v0, %vf0
      #|  Ret %vf1
      #|}
      #|
    ),
  )
}

///|
/// Test constant array access  
/// int constant_array_test() {
///   int arr[3] = {1, 2, 3};
///   return arr[1];
/// }
test "Simple IRTranslate - constant array access" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [])
  let fval = mod.addFunction(fty, "constant_array_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)

  // Create a local array
  let arr_alloca = builder.createAlloca(i32ty)

  // Store some values
  let val1 = ctx.getConstInt32(1)
  //let val2 = ctx.getConstInt32(2)
  //let val3 = ctx.getConstInt32(3)

  let _ = builder.createStore(val1, arr_alloca)

  // Load and return value
  let result = builder.createLoad(i32ty, arr_alloca)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func constant_array_test() {
      #|entry:
      #|  Storel (fp' - 4), 1
      #|  %v0 = Loadl (fp' - 4)
      #|  Ret %v0
      #|}
      #|
    ),
  )
}

///|
/// Test proper struct access with GEP
/// struct Point { int x; int y; };
/// int struct_access_test(struct Point* p) {
///   return p->x + p->y;
/// }
test "Simple IRTranslate - proper struct access" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let point_ty = ctx.getStructType([i32ty, i32ty], name="Point")
  let ptr_ty = ctx.getPtrTy()
  let fty = ctx.getFunctionType(i32ty, [ptr_ty])
  let fval = mod.addFunction(fty, "struct_access_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let p = fval.getArg(0).unwrap()
  let zero = ctx.getConstInt32(0)
  let one = ctx.getConstInt32(1)

  // Access p->x (field 0) using GEP with proper indices
  let gep_x = builder.createGEP(p, point_ty, [zero, zero])
  let val_x = builder.createLoad(i32ty, gep_x)

  // Access p->y (field 1) using GEP with proper indices
  let gep_y = builder.createGEP(p, point_ty, [zero, one])
  let val_y = builder.createLoad(i32ty, gep_y)
  let sum = builder.createAdd(val_x, val_y)
  let _ = builder.createRet(sum)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func struct_access_test(%v0) {
      #|entry:
      #|  %v1 = Loadl %v0
      #|  %v2 = Addq %v0, 8
      #|  %v3 = Loadl %v2
      #|  %v4 = Addl %v1, %v3
      #|  Ret %v4
      #|}
      #|
    ),
  )
}

///|
/// Test floating point constants
/// float float_constants() {
///   return 3.14 + (-2.5);
/// }
test "Simple IRTranslate - constants float" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let f32ty = ctx.getFloatTy()
  let fty = ctx.getFunctionType(f32ty, [])
  let fval = mod.addFunction(fty, "float_constants")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let pi = ctx.getConstFloat(3.14)
  let neg_val = ctx.getConstFloat(-2.5)
  let result = builder.createFAdd(pi, neg_val)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func float_constants() {
      #|entry:
      #|  %vf0 = FAddS 3.140000104904175, -2.5
      #|  Ret %vf0
      #|}
      #|
    ),
  )
}

///|
/// Test boolean constants
/// int bool_constants(int x) {
///   return x == 0 ? 1 : 0;
/// }
test "Simple IRTranslate - constants bool" {
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
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func bool_constants(%v0) {
      #|entry:
      #|  %v1 = Eq %v0, 0
      #|  %v2 = Select %v1, 1, 0
      #|  Ret %v2
      #|}
      #|
    ),
  )
}

///|
/// Test zero constants
/// void zero_constants() {
///   int x = 0;
///   float f = 0.0;
/// }
test "Simple IRTranslate - constants zero" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let f32ty = ctx.getFloatTy()
  let void_ty = ctx.getVoidTy()
  let fty = ctx.getFunctionType(void_ty, [])
  let fval = mod.addFunction(fty, "zero_constants")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let x_alloca = builder.createAlloca(i32ty)
  let f_alloca = builder.createAlloca(f32ty)
  let zero_int = ctx.getConstInt32(0)
  let zero_float = ctx.getConstFloat(0.0)
  let _ = builder.createStore(zero_int, x_alloca)
  let _ = builder.createStore(zero_float, f_alloca)
  let _ = builder.createRetVoid()
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func zero_constants() {
      #|entry:
      #|  Storel (fp' - 4), 0
      #|  Storel (fp' - 8), 0
      #|  Ret 
      #|}
      #|
    ),
  )
}

///|
/// Test array access patterns
/// int array_sum(int arr[3]) {
///   return arr[0] + arr[1] + arr[2];
/// }
test "Simple IRTranslate - array operations" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  //let arr_ty = ctx.getArrayType(i32ty, 3)
  let ptr_ty = ctx.getPtrTy()
  let fty = ctx.getFunctionType(i32ty, [ptr_ty])
  let fval = mod.addFunction(fty, "array_sum")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let arr = fval.getArg(0).unwrap()
  let zero = ctx.getConstInt32(0)
  let one = ctx.getConstInt32(1)
  let two = ctx.getConstInt32(2)

  // Access arr[0]
  let gep0 = builder.createGEP(arr, i32ty, [zero])
  let val0 = builder.createLoad(i32ty, gep0)

  // Access arr[1] 
  let gep1 = builder.createGEP(arr, i32ty, [one])
  let val1 = builder.createLoad(i32ty, gep1)

  // Access arr[2]
  let gep2 = builder.createGEP(arr, i32ty, [two])
  let val2 = builder.createLoad(i32ty, gep2)

  // Sum them up
  let sum1 = builder.createAdd(val0, val1)
  let total = builder.createAdd(sum1, val2)
  let _ = builder.createRet(total)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func array_sum(%v0) {
      #|entry:
      #|  %v1 = Loadl %v0
      #|  %v2 = Addq %v0, 4
      #|  %v3 = Loadl %v2
      #|  %v4 = Addq %v0, 8
      #|  %v5 = Loadl %v4
      #|  %v6 = Addl %v1, %v3
      #|  %v7 = Addl %v6, %v5
      #|  Ret %v7
      #|}
      #|
    ),
  )
}

///|
/// Test constant array access  
/// int constant_array_test() {
///   int arr[3] = {1, 2, 3};
///   return arr[1];
/// }
test "Simple IRTranslate - constant array access" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [])
  let fval = mod.addFunction(fty, "constant_array_test")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)

  // Create a local array
  let arr_alloca = builder.createAlloca(i32ty)

  // Store some values
  let val1 = ctx.getConstInt32(1)
  //let val2 = ctx.getConstInt32(2)
  //let val3 = ctx.getConstInt32(3)

  let _ = builder.createStore(val1, arr_alloca)

  // Load and return value
  let result = builder.createLoad(i32ty, arr_alloca)
  let _ = builder.createRet(result)
  let mir_func = @GMIR.Function::from_llvm_function(fval, rv64_config)
  inspect(
    mir_func,
    content=(
      #|func constant_array_test() {
      #|entry:
      #|  Storel (fp' - 4), 1
      #|  %v0 = Loadl (fp' - 4)
      #|  Ret %v0
      #|}
      #|
    ),
  )
}

///|
/// 
/// void print_string(const char* s);
///
/// int main() {
///   print_string("Hello, World!\n");
///   return 0;
/// }
/// }
test "Simple IRTranslate - global string" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let ptr_ty = ctx.getPtrTy()
  let void_ty = ctx.getVoidTy()

  // Declare external function
  let print_fty = ctx.getFunctionType(void_ty, [ptr_ty])
  let print_func = mod.addFunction(print_fty, "print_string")

  // Create main function
  let main_fty = ctx.getFunctionType(i32ty, [])
  let main_func = mod.addFunction(main_fty, "main")
  let main_bb = main_func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(main_bb)

  // Create global string
  let global_str = mod.addGlobalString("Hello, World!\n")
  global_str.setLinkage(Private)
  global_str.setUnnamedAddr(Local)

  // Call print_string
  let _ = builder.createCall(print_func, [global_str])

  // Return 0
  let zero = ctx.getConstInt32(0)
  let _ = builder.createRet(zero)
  let mod = @GMIR.Module::new(mod, rv64_config)
  mod.run_ir_translation()
  let expected =
    #|global gstr1 {
    #|  "Hello, World!\n"
    #|}
    #|
    #|func main() {
    #|entry:
    #|  %v0 = Movq gstr1
    #|  Call print_string, %v0
    #|  Ret 0
    #|}
    #|
    #|
  inspect(mod, content=expected)
}
