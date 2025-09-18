///|
fn main {
  try {
    // Test function parameter spilling
    println("=== Testing Function Parameter Spilling ===\n")
    
    let ctx = @IR.Context::new()
    let mod = ctx.addModule("test")
    let i32ty = ctx.getInt32Ty()
    
    // Create a function with 8 parameters
    let param_types : Array[&@IR.Type] = []
    for i = 0; i < 8; i = i + 1 {
      param_types.push(i32ty)
    }
    
    let fty = ctx.getFunctionType(i32ty, param_types)
    let func = mod.addFunction(fty, "eight_params")
    let bb = func.addBasicBlock(name="entry")
    let builder = ctx.createBuilder()
    builder.setInsertPoint(bb)
    
    // Sum all parameters
    let mut sum : &@IR.Value = func.getArg(0).unwrap()
    for i = 1; i < 8; i = i + 1 {
      let arg : &@IR.Value = func.getArg(i).unwrap()
      sum = builder.createAdd(sum, arg)
    }
    let _ = builder.createRet(sum)
    
    // Convert to MIR
    let mir_func = @GMIR.Function::from_llvm_function(func)
    println("Original MIR:")
    println(mir_func)
    
    // Legalize with only 4 registers
    let config = @GMIR.LegalizeConfig::{
      max_num_call_regs: 4,
      max_num_call_fregs: 4
    }
    let legalized_func = @GMIR.legalize_func(mir_func, config)
    
    println("\nAfter Legalize:")
    println(legalized_func)
    
    // Analyze parameters
    println("\n=== Parameter Analysis ===")
    for i, param in legalized_func.params {
      match param {
        @GMIR.VReg(id) => println("Param \{i}: VReg(\{id}) - kept in register")
        @GMIR.Mem(_, offset) => println("Param \{i}: Mem(sp + \{offset}) - spilled to stack")
        _ => println("Param \{i}: \{param}")
      }
    }
    
    // Count parameter types
    let mut reg_params = 0
    let mut mem_params = 0
    for param in legalized_func.params {
      match param {
        @GMIR.VReg(_) => reg_params += 1
        @GMIR.Mem(_, _) => mem_params += 1
        _ => ()
      }
    }
    
    println("\nSummary:")
    println("  Parameters in registers: \{reg_params}")
    println("  Parameters on stack: \{mem_params}")
    
    if reg_params == 4 && mem_params == 4 {
      println("✓ Parameter spilling working correctly!")
    } else {
      println("✗ Parameter spilling not working as expected")
    }
    
    // Now test Call instruction spilling
    println("\n\n=== Testing Call Instruction Spilling ===\n")
    
    let caller_fty = ctx.getFunctionType(i32ty, [])
    let caller_func = mod.addFunction(caller_fty, "caller")
    let caller_bb = caller_func.addBasicBlock(name="entry")
    builder.setInsertPoint(caller_bb)
    
    // Call the eight_params function with constants
    let call_args : Array[&@IR.Value] = []
    for i = 1; i <= 8; i = i + 1 {
      call_args.push(ctx.getConstInt32(i))
    }
    
    let result = builder.createCall(func, call_args)
    let _ = builder.createRet(result)
    
    let mir_caller = @GMIR.Function::from_llvm_function(caller_func)
    println("Original Caller MIR:")
    println(mir_caller)
    
    let legalized_caller = @GMIR.legalize_func(mir_caller, config)
    println("\nLegalized Caller MIR:")
    println(legalized_caller)
    
    // Analyze the Call instruction
    let mut found_call = false
    let mut store_count = 0
    let mut mem_args_in_call = 0
    
    for bb in legalized_caller.body {
      for inst in bb.insts {
        match inst.opcode {
          @GMIR.Storeq => store_count += 1
          @GMIR.Call => {
            found_call = true
            for use_op in inst.uses {
              match use_op {
                @GMIR.Mem(_, _) => mem_args_in_call += 1
                _ => ()
              }
            }
          }
          _ => ()
        }
      }
    }
    
    println("\nCall Instruction Analysis:")
    println("  Store instructions generated: \{store_count}")
    println("  Memory arguments in Call: \{mem_args_in_call}")
    
    if store_count == 4 && mem_args_in_call == 4 {
      println("✓ Call argument spilling working correctly!")
    } else {
      println("✗ Call argument spilling not working as expected")
    }
    
  } catch {
    e => println("Error: \{e}")
  }
}