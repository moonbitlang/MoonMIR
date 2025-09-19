
//let rv64_config:@GMIR.ArchConfig  = @GMIR.ArchConfig::riscv64()
let debug_config:@GMIR.ArchConfig  = @GMIR.ArchConfig::debug()

///|
/// 10 number add
/// int sum(int a1, int a2, int a3, int a4, int a5, int a6, int a7, int a8, int a9, int a10) {
///   return a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10;
/// }
///
/// int main() {
///   return sum(1,2,3,4,5,6,7,8,9,10);
/// }
fn main_err() -> Unit raise {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()

  let sum_arg_ty: Array[&@IR.Type] = [
    i32ty, i32ty, i32ty, i32ty, i32ty,
    i32ty, i32ty, i32ty, i32ty, i32ty
  ]
  let sum_func_ty = ctx.getFunctionType(i32ty, sum_arg_ty)
  let sum_func = mod.addFunction(sum_func_ty, "sum")
  let sum_bb = sum_func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(sum_bb)
  let a0 = sum_func.getArg(0).unwrap()
  let a1 = sum_func.getArg(1).unwrap()
  let a2 = sum_func.getArg(2).unwrap()
  let a3 = sum_func.getArg(3).unwrap()
  let a4 = sum_func.getArg(4).unwrap()
  let a5 = sum_func.getArg(5).unwrap()
  let a6 = sum_func.getArg(6).unwrap()
  let a7 = sum_func.getArg(7).unwrap()
  let a8 = sum_func.getArg(8).unwrap()
  let a9 = sum_func.getArg(9).unwrap()
  let sum1 = builder.createAdd(a0, a1)
  let sum2 = builder.createAdd(sum1, a2)
  let sum3 = builder.createAdd(sum2, a3)
  let sum4 = builder.createAdd(sum3, a4)
  let sum5 = builder.createAdd(sum4, a5)
  let sum6 = builder.createAdd(sum5, a6)
  let sum7 = builder.createAdd(sum6, a7)
  let sum8 = builder.createAdd(sum7, a8)
  let sum9 = builder.createAdd(sum8, a9)
  let _ = builder.createRet(sum9)

  let main_func_ty = ctx.getFunctionType(i32ty, [])
  let main_func = mod.addFunction(main_func_ty, "main")
  let main_bb = main_func.addBasicBlock(name="entry")
  builder.setInsertPoint(main_bb)
  let one = ctx.getConstInt32(1)
  let two = ctx.getConstInt32(2)
  let three = ctx.getConstInt32(3)
  let four = ctx.getConstInt32(4)
  let five = ctx.getConstInt32(5)
  let six = ctx.getConstInt32(6)
  let seven = ctx.getConstInt32(7)
  let eight = ctx.getConstInt32(8)
  let nine = ctx.getConstInt32(9)
  let ten = ctx.getConstInt32(10)
  let args: Array[&@IR.Value] = [one, two, three, four, five, six, seven, eight, nine, ten]
  let call = builder.createCall(sum_func, args)
  let _ = builder.createRet(call)

  // print llvm module
  println(mod)

  // translate to machine IR
  let machine_mod = @GMIR.Module::new(mod, debug_config)
  machine_mod.run_ir_translation()
  println(machine_mod)
}

fn main {
  main_err() catch {
    e => { println("Error: \{e}"); return ;}
  }
}

