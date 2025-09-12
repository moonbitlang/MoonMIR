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

fn rv_cvt(llvm_module: () -> @IR.Module raise?) -> Unit raise {
  let mod = llvm_module()
  println("==================== LLVM IR ================")
  mod.dump()
  println("==================== GMIR ================")
  let gmir = @GMIR.Module::from_llvm_module(mod)
  println(gmir)
  println("==================== GMIR Legalized ================")
  let gmir = gmir.legalize()
  println(gmir)
  println("==================== GMIR RegAlloc ================")
  let gmir = gmir.reg_alloc(max_num_reg = 17, max_num_freg = 17)
  println(gmir)
  println("==================== GMIR PostRA Adjustment ================")
  let gmir = gmir.post_ra_adjustments()
  println(gmir)
  println("==================== GMIR PostRA Peephole Optimazation ================")
  let gmir = gmir.peephole_optimizations()
  println(gmir)
  println("==================== RISCV ================")
  let riscv_asm = @riscv.from_gmir_module(gmir)
  fn print_asm(inst : @riscv.RvAsm) {
    match inst {
      Label(_) as l => println(l)
      inst => println("  \{inst}")
    }
  }

  riscv_asm.each(line => print_asm(line))
}

///|
fn main {
  //rv_cvt(llvm_ret42) catch {
  //  e => println(e)
  //}
  //let help_info = "usage: mbtasmbler "
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
    #|  --stop-after=RISCV              Stop after RISCV assembly generation
    #|  --print-all                     Print all intermediate representations
    #|
    #|Input:
    #|  input=demo_add                  Use Builtin demo_add (default)
    #|  input=demo_ret42                Use Builtin demo_ret42
    #|  input=demo_fib                  Use Builtin demo_fib

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
  } else {
    println("Error: Unknown input")
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
