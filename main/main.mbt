fn llvm_add() -> @IR.Module raise {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let func = mod.addFunction(fty, "add")
  let bb = func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let a = func.getArg(0).unwrap()
  let b = func.getArg(1).unwrap()
  let res = builder.createAdd(a, b)
  let _ = builder.createRet(res)
  return mod
}

fn llvm_ret42() -> @IR.Module raise {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty = ctx.getFunctionType(i32ty, [])
  let func = mod.addFunction(fty, "main")
  let bb = func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  let val = ctx.getConstInt32(42)
  let _ = builder.createRet(val)
  return mod
}

// int sum(int a, int b, int c, int d, int e) { return a + b + c + d + e; }
// int main() { return sum(1, 2, 3, 4, 5); }

fn llvm_simple_call() -> @IR.Module raise {
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("demo")
  let i32ty = ctx.getInt32Ty()
  let fty_sum = ctx.getFunctionType(i32ty, [i32ty, i32ty, i32ty, i32ty, i32ty])
  let func_sum = mod.addFunction(fty_sum, "sum")
  let bb_sum = func_sum.addBasicBlock(name="entry")
  let builder_sum = ctx.createBuilder()
  builder_sum.setInsertPoint(bb_sum)
  let a = func_sum.getArg(0).unwrap()
  let b = func_sum.getArg(1).unwrap()
  let c = func_sum.getArg(2).unwrap()
  let d = func_sum.getArg(3).unwrap()
  let e = func_sum.getArg(4).unwrap()
  let res1 = builder_sum.createAdd(a, b)
  let res2 = builder_sum.createAdd(res1, c)
  let res3 = builder_sum.createAdd(res2, d)
  let res4 = builder_sum.createAdd(res3, e)
  let _ = builder_sum.createRet(res4)

  let fty_main = ctx.getFunctionType(i32ty, [])
  let func_main = mod.addFunction(fty_main, "main")
  let bb_main = func_main.addBasicBlock(name="entry")
  let builder_main = ctx.createBuilder()
  builder_main.setInsertPoint(bb_main)
  let arg1 = ctx.getConstInt32(1)
  let arg2 = ctx.getConstInt32(2)
  let arg3 = ctx.getConstInt32(3)
  let arg4 = ctx.getConstInt32(4)
  let arg5 = ctx.getConstInt32(5)
  let call_inst = builder_main.createCall(func_sum, [arg1, arg2, arg3, arg4, arg5])
  let _ = builder_main.createRet(call_inst)

  return mod
}

///|
fn main {
  let help_info = 
    #|Usage: mbtasmbler [options] <input>
    #|
    #|Options:
    #|  -h, --help                      Show this help message
    #|  --stop-after=llvm               Stop after LLVM IR generation
    #|  --stop-after=IRTranslate        Stop after GMIR generation
    #|  --stop-after=Legalize           Stop after GMIR legalization
    #|  --stop-after=RegAlloc           Stop after GMIR register allocation
    #|  --stop-after=PostRAAdjustments  Stop after GMIR post-RA adjustments
    #|  --stop-after=PeepholeOpt        Stop after GMIR peephole optimizations
    #|  --print-all                     Print all intermediate representations
    #|
    #|Input:
    #|  input=demo_add                  Use Builtin demo_add (default)
    #|  input=demo_ret42                Use Builtin demo_ret42
    #|  input=demo_simple_call          Use Builtin demo_simple_call

  let args = @env.args()

  // Print Help Info if no args or -h/--help is provided
  if args.length() < 2 || args.contains("-h") || args.contains("--help") {
    println(help_info)
    return
  }

  let mod = if args.contains("input=demo_add") {
    (try? llvm_add()).unwrap()
  } else if args.contains("input=demo_ret42") {
    (try? llvm_ret42()).unwrap()
  } else if args.contains("input=demo_simple_call") {
    (try? llvm_simple_call()).unwrap()
  } else {
    println("Error: Must give input")
    println(help_info)
    return
  }

  if args.contains("--stop-after=llvm") {
    mod.dump()
    return
  }

  if args.contains("--print-all") {
    println("==================== LLVM IR ================")
    mod.dump()
  }

  let gmir = @GMIR.Module::from_llvm_module(mod) catch {
    e => {
      println("Error during GMIR translation: \{e}")
      return
    }
  }

  if args.contains("--stop-after=IRTranslate") {
    println(gmir)
    return
  }

  if args.contains("--print-all") {
    println("==================== GMIR ================")
    println(gmir)
  }

  let gmir = gmir.legalize() catch {
    e => {
      println("Error during GMIR legalization: \{e}")
      return
    }
  }

  if args.contains("--stop-after=Legalize") {
    println(gmir)
    return
  }

  if args.contains("--print-all") {
    println("==================== GMIR Legalized ================")
    println(gmir)
  }

  let gmir = gmir.reg_alloc(max_num_reg = 17, max_num_freg = 17) catch {
    e => {
      println("Error during GMIR register allocation: \{e}")
      return
    }
  }

  if args.contains("--stop-after=RegAlloc") {
    println(gmir)
    return
  }

  if args.contains("--print-all") {
    println("==================== GMIR RegAlloc ================")
    println(gmir)
  }

  let gmir = gmir.post_ra_adjustments() catch {
    e => {
      println("Error during GMIR post-RA adjustments: \{e}")
      return
    }
  }

  if args.contains("--stop-after=PostRAAdjustments") {
    println(gmir)
    return
  }

  if args.contains("--print-all") {
    println("==================== GMIR PostRA Adjustment ================")
    println(gmir)
  }

  let gmir = gmir.peephole_optimizations()

  if args.contains("--stop-after=PeepholeOpt") {
    println(gmir)
    return
  }

  if args.contains("--print-all") {
    println("==================== GMIR PostRA Peephole Optimazation ================")
    println(gmir)
  }

  let riscv_asm = @riscv.from_gmir_module(gmir) catch {
    e => {
      println("Error during RISCV assembly generation: \{e}")
      return
    }
  }

  fn print_asm(inst : @riscv.RvAsm) {
    match inst {
      Label(_) as l => println(l)
      inst => println("  \{inst}")
    }
  }

  riscv_asm.each(line => print_asm(line))
}
