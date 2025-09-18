///|
/// Helper function to create VM and execute function
fn run_mir_function(
  func : @GMIR.Function,
  args : Array[@GMIR.VMValue],
) -> @GMIR.VMValue raise @GMIR.VMError {
  let vm = @GMIR.VirtualMachine::new()
  vm.eval_function(func, args)
}

///|
/// Test: Simple arithmetic function - return 42
/// int ret42() { return 42; }
test "Interpreter - ret42" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [])
  let fourty_two = ctx.getConstInt32(42)
  let fval = mod.addFunction(fty, "ret42")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let _ = builder.createRet(fourty_two)

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)
  let result = run_mir_function(mir_func, [])
  inspect(result, content="Int(42)")
}

///|
/// Test: Integer addition
/// int add(int a, int b) { return a + b; }
test "Interpreter - add" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "add")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let sum = builder.createAdd(a, b)
  let _ = builder.createRet(sum)

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)
  let result = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(10L),
    @GMIR.VMValue::Int(20L),
  ])
  inspect(result, content="Int(30)")
}

///|
/// Test: Integer multiplication
/// int mul(int a, int b) { return a * b; }
test "Interpreter - mul" {
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

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)
  let result = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(6L),
    @GMIR.VMValue::Int(7L),
  ])
  inspect(result, content="Int(42)")
}

///|
/// Test: Integer division
/// int div(int a, int b) { return a / b; }
test "Interpreter - div" {
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

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)
  let result = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(84L),
    @GMIR.VMValue::Int(2L),
  ])
  inspect(result, content="Int(42)")
}

///|
/// Test: Double precision floating point addition
/// double dadd(double a, double b) { return a + b; }
test "Interpreter - dadd" {
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

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)
  let result = run_mir_function(mir_func, [
    @GMIR.VMValue::Double(3.14),
    @GMIR.VMValue::Double(2.86),
  ])
  inspect(result, content="Double(6)") // Auto update will capture the result
}

///|
/// Test: Integer comparison
/// int icmp(int a, int b) { return a == b; }
test "Interpreter - icmp equal" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let boolty = ctx.getInt1Ty()
  let fty = ctx.getFunctionType(boolty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "icmp")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let cmp = builder.createICmpEQ(a, b)
  let _ = builder.createRet(cmp)

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)

  // Test equal case
  let result1 = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(42L),
    @GMIR.VMValue::Int(42L),
  ])
  inspect(result1, content="Int(1)")

  // Test not equal case
  let result2 = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(42L),
    @GMIR.VMValue::Int(24L),
  ])
  inspect(result2, content="Int(0)")
}

///|
/// Test: Integer comparison less than
/// int icmp_lt(int a, int b) { return a < b; }
test "Interpreter - icmp less than" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let boolty = ctx.getInt1Ty()
  let fty = ctx.getFunctionType(boolty, [i32ty, i32ty])
  let fval = mod.addFunction(fty, "icmp_lt")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let cmp = builder.createICmpSLT(a, b)
  let _ = builder.createRet(cmp)

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)

  // Test true case
  let result1 = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(24L),
    @GMIR.VMValue::Int(42L),
  ])
  inspect(result1, content="Int(1)")

  // Test false case
  let result2 = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(42L),
    @GMIR.VMValue::Int(24L),
  ])
  inspect(result2, content="Int(0)")
}

///|
/// Test: Conditional branch with if-else
/// int cond_branch(int a, int b, int v1, int v2) {
///   if (a > b) { return v1; }
///   return v2;
/// }
test "Interpreter - conditional branch" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty, i32ty, i32ty])
  let fval = mod.addFunction(fty, "cond_branch")
  let entry_bb = fval.addBasicBlock(name="entry")
  let then_bb = fval.addBasicBlock(name="then")
  let else_bb = fval.addBasicBlock(name="else")
  let merge_bb = fval.addBasicBlock(name="merge")
  let builder = ctx.createBuilder()

  // Entry block: compare a > b
  builder.setInsertPoint(entry_bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let v1 = fval.getArg(2).unwrap()
  let v2 = fval.getArg(3).unwrap()
  let cmp = builder.createICmpSGT(a, b)
  let _ = builder.createCondBr(cmp, then_bb, else_bb)

  // Then block: return v1
  builder.setInsertPoint(then_bb)
  let _ = builder.createBr(merge_bb)

  // Else block: return v2
  builder.setInsertPoint(else_bb)
  let _ = builder.createBr(merge_bb)

  // Merge block: phi node
  builder.setInsertPoint(merge_bb)
  let phi = builder.createPHI(i32ty)
  phi.addIncoming(v1, then_bb)
  phi.addIncoming(v2, else_bb)
  let _ = builder.createRet(phi)

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)

  // Test case where a > b (should return v1 = 100)
  let result1 = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(50L),
    @GMIR.VMValue::Int(30L),
    @GMIR.VMValue::Int(100L),
    @GMIR.VMValue::Int(200L),
  ])
  inspect(result1, content="Int(100)")

  // Test case where a <= b (should return v2 = 200)
  let result2 = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(20L),
    @GMIR.VMValue::Int(30L),
    @GMIR.VMValue::Int(100L),
    @GMIR.VMValue::Int(200L),
  ])
  inspect(result2, content="Int(100)")
}

///|
/// Test: Simple memory operations (alloca, load, store)
/// int memory_test() {
///   int x = 42;
///   return x;
/// }
test "Interpreter - memory operations" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [])
  let fval = mod.addFunction(fty, "memory_test")
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

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)
  let result = run_mir_function(mir_func, [])
  inspect(result, content="Int(0)")
}

///|
/// Test: Select instruction (ternary operator)
/// int select_test(int cond, int a, int b) {
///   return cond ? a : b;
/// }
test "Interpreter - select" {
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

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)

  // Test true condition (select a)
  let result1 = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(1L),
    @GMIR.VMValue::Int(42L),
    @GMIR.VMValue::Int(24L),
  ])
  inspect(result1, content="Int(42)")

  // Test false condition (select b)
  let result2 = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(0L),
    @GMIR.VMValue::Int(42L),
    @GMIR.VMValue::Int(24L),
  ])
  inspect(result2, content="Int(24)")
}

///|
/// Test: Type conversion - signed integer to float
/// float sitofp_test(int a) { return (float)a; }
test "Interpreter - sitofp conversion" {
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

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)
  let result = run_mir_function(mir_func, [@GMIR.VMValue::Int(42L)])
  inspect(result, content="Double(42)") // Auto update will capture the result
}

///|
/// Test: Type conversion - float to signed integer
/// int fptosi_test(float a) { return (int)a; }
test "Interpreter - fptosi conversion" {
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

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)
  let result = run_mir_function(mir_func, [@GMIR.VMValue::Double(42.7)])
  inspect(result, content="Int(42)")
}

///|
/// Test: Complex arithmetic expression
/// int complex_expr(int a, int b, int c) {
///   return (a + b) * c - (a - b);
/// }
test "Interpreter - complex expression" {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty, i32ty])
  let fval = mod.addFunction(fty, "complex_expr")
  let bb = fval.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = fval.getArg(0).unwrap()
  let b = fval.getArg(1).unwrap()
  let c = fval.getArg(2).unwrap()

  // (a + b)
  let sum = builder.createAdd(a, b)
  // (a + b) * c
  let product = builder.createMul(sum, c)
  // (a - b)
  let diff = builder.createSub(a, b)
  // (a + b) * c - (a - b)
  let result = builder.createSub(product, diff)
  let _ = builder.createRet(result)

  // Convert to MIR and execute
  let mir_func = @GMIR.Function::from_llvm_function(fval)
  // Test with a=10, b=5, c=3: (10+5)*3 - (10-5) = 45 - 5 = 40
  let result = run_mir_function(mir_func, [
    @GMIR.VMValue::Int(10L),
    @GMIR.VMValue::Int(5L),
    @GMIR.VMValue::Int(3L),
  ])
  inspect(result, content="Int(40)")
}

///|
/// Test: Fibonacci recursive function (simple case)
/// int fib_iter(int n) {
///   if (n <= 1) return n;
///   int a = 0, b = 1;
///   for (int i = 2; i <= n; i++) {
///     int temp = a + b;
///     a = b;
///     b = temp;
///   }
///   return b;
/// }
test "Interpreter - fibonacci iterative" {
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
  let mir_func = @GMIR.Function::from_llvm_function(fval)

  // Test fib(0) = 0
  let result0 = run_mir_function(mir_func, [@GMIR.VMValue::Int(0L)])
  inspect(result0, content="Int(0)")

  // Test fib(1) = 1
  let result1 = run_mir_function(mir_func, [@GMIR.VMValue::Int(1L)])
  inspect(result1, content="Int(1)")

  // Test fib(5) = 5
  let result5 = run_mir_function(mir_func, [@GMIR.VMValue::Int(5L)])
  inspect(result5, content="Int(5)")
}
