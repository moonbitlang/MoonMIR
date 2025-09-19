//let rv64_config:@GMIR.ArchConfig  = @GMIR.ArchConfig::riscv64()

///|
let debug_config : @GMIR.ArchConfig = @GMIR.ArchConfig::debug()

///|
/// Test function with local variables
/// int test_local() {
///   int x = 42;
///   int y = 24;
///   int *ptr = &x;
///   return x + y + *ptr;
/// }
///
/// int main() {
///   return test_local();
/// }
fn main_err() -> Unit raise {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()

  // Create test_local function with local variables
  let test_local_func_ty = ctx.getFunctionType(i32ty, [])
  let test_local_func = mod.addFunction(test_local_func_ty, "test_local")
  let test_local_bb = test_local_func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(test_local_bb)

  // int x = 42;
  let x_alloca = builder.createAlloca(i32ty)
  let const42 = ctx.getConstInt32(42)
  let _ = builder.createStore(const42, x_alloca)

  // int y = 24;
  let y_alloca = builder.createAlloca(i32ty)
  let const24 = ctx.getConstInt32(24)
  let _ = builder.createStore(const24, y_alloca)

  // int z = 10;
  let z_alloca = builder.createAlloca(i32ty)
  let const10 = ctx.getConstInt32(10)
  let _ = builder.createStore(const10, z_alloca)

  // Load values: x, y, z
  let x_val = builder.createLoad(i32ty, x_alloca)
  let y_val = builder.createLoad(i32ty, y_alloca)
  let z_val = builder.createLoad(i32ty, z_alloca)

  // return x + y + z;
  let sum1 = builder.createAdd(x_val, y_val)
  let result = builder.createAdd(sum1, z_val)
  let _ = builder.createRet(result)

  // Create main function
  let main_func_ty = ctx.getFunctionType(i32ty, [])
  let main_func = mod.addFunction(main_func_ty, "main")
  let main_bb = main_func.addBasicBlock(name="entry")
  builder.setInsertPoint(main_bb)
  let call = builder.createCall(test_local_func, [])
  let _ = builder.createRet(call)

  // print llvm module
  println(mod)

  // translate to machine IR
  let machine_mod = @GMIR.Module::new(mod, debug_config)
  machine_mod.run_ir_translation()
  println("=== After IR Translation ===")
  println(machine_mod)

  // run register allocation with limited registers to force spilling
  let regalloced_mod = machine_mod.reg_alloc(max_num_reg=2, max_num_freg=2) // Very limited registers
  println(
    "\n=== After Register Allocation with Limited Registers (Prologue/Epilogue) ===",
  )
  println(regalloced_mod)

  // Test RISC-V conversion to ensure prologue/epilogue works correctly
  let rv_insts = @riscv.from_gmir_module(regalloced_mod)
  println("\n=== RISC-V Assembly ===")
  for inst in rv_insts {
    println(inst)
  }
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
