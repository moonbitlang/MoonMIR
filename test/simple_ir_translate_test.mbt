
///|
/// int ret42() { retun 42; }
test "Simple IRTranslate - ret42" {
  let ctx = @IR.Context::new();
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()

  // ret42
  let fty = ctx.getFunctionType(i32ty, []);
  let fourty_two = ctx.getConstInt32(42);
  let fval = mod.addFunction(fty, "ret42",);
  let bb = fval.addBasicBlock(name="entry");
  let builder = ctx.createBuilder();
  builder.setInsertPoint(bb);
  let _ = builder.createRet(fourty_two);

  let mir_func = @GMIR.Function::from_llvm_function(fval)
  //println(mir_func)
  let expected = 
    #|func ret42() {
    #|entry:
    #|  Ret 42
    #|}
    #|

  inspect(mir_func, content=expected);
}

///|
///
/// int add(int a, int b) { return a + b; }
test "Simple IRTranslate - add" {
  let ctx = @IR.Context::new();
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()

  // add
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty]);
  let fval = mod.addFunction(fty, "add",);
  let bb = fval.addBasicBlock(name="entry");
  let builder = ctx.createBuilder();
  builder.setInsertPoint(bb);
  let a = fval.getArg(0).unwrap();
  let b = fval.getArg(1).unwrap();
  let sum = builder.createAdd(a, b);
  let _ = builder.createRet(sum);

  let mir_func = @GMIR.Function::from_llvm_function(fval)
  let expected = 
    #|func add(%v0, %v1) {
    #|entry:
    #|  %v2 = Addl %v0, %v1
    #|  Ret %v2
    #|}
    #|

  inspect(mir_func, content=expected);
}

///|
///
/// int icmp(int a, int b) { return a == b; }
test "Simple IRTranslate - icmp" {
  let ctx = @IR.Context::new();
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let boolty = ctx.getInt1Ty()

  // icmp
  let fty = ctx.getFunctionType(boolty, [i32ty, i32ty]);
  let fval = mod.addFunction(fty, "icmp",);
  let bb = fval.addBasicBlock(name="entry");
  let builder = ctx.createBuilder();
  builder.setInsertPoint(bb);
  let a = fval.getArg(0).unwrap();
  let b = fval.getArg(1).unwrap();
  let cmp = builder.createICmpEQ(a, b);
  let _ = builder.createRet(cmp);

  let mir_func = @GMIR.Function::from_llvm_function(fval)
  let expected = 
    #|func icmp(%v0, %v1) {
    #|entry:
    #|  %v2 = Eq %v0, %v1
    #|  Ret %v2
    #|}
    #|

  inspect(mir_func, content=expected);
}

///|
/// int cond_branch(int a, int b, int v1, int v2) {
///   if (a > b) { return v1; }
///   return v2;
/// }
test "Simple IRTranslate - cond branch" {
  let ctx = @IR.Context::new();
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()

  // cond_branch
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty, i32ty, i32ty]);
  let fval = mod.addFunction(fty, "cond_branch",);
  let entry_bb = fval.addBasicBlock(name="entry");
  let then_bb = fval.addBasicBlock(name="then");
  let else_bb = fval.addBasicBlock(name="else");
  let merge_bb = fval.addBasicBlock(name="merge");

  let builder = ctx.createBuilder();
  builder.setInsertPoint(entry_bb);
  let a = fval.getArg(0).unwrap();
  let b = fval.getArg(1).unwrap();
  let v1 = fval.getArg(2).unwrap();
  let v2 = fval.getArg(3).unwrap();
  let cmp = builder.createICmpSGT(a, b);
  let _ = builder.createCondBr(cmp, then_bb, else_bb);

  builder.setInsertPoint(then_bb);
  let _ = builder.createBr(merge_bb);

  builder.setInsertPoint(else_bb);
  let _ = builder.createBr(merge_bb);

  builder.setInsertPoint(merge_bb);
  let phi = builder.createPHI(i32ty);
  phi.addIncoming(v1, then_bb);
  phi.addIncoming(v2, else_bb);
  let _ = builder.createRet(phi);

  let mir_func = @GMIR.Function::from_llvm_function(fval)
  println(mir_func)
  let expected = 
    #|func cond_branch(%v0, %v1, %v2, %v3) {
    #|entry:
    #|  Bgt %v0, %v1, then, else
    #|then:
    #|  Jmp merge
    #|else:
    #|  Jmp merge
    #|merge:
    #|  %v4 = PHI %v2, %v3
    #|  Ret %v4
    #|}
    #|

  inspect(mir_func, content=expected);
}
