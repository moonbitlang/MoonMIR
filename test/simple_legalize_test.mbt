///|
/// Test for Legalize functionality
/// This tests that function parameters and call arguments are properly spilled
/// when they exceed the available registers

test "legalize_call_instruction_spillage" {
  // Test that Call instructions properly generate spill code
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("test")
  let i32ty = ctx.getInt32Ty()
  
  // Create a caller that calls a function with many arguments
  let caller_fty = ctx.getFunctionType(i32ty, [])
  let caller_func = mod.addFunction(caller_fty, "caller")
  let bb = caller_func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  
  // Create a call with 8 arguments
  let callee_types : Array[&@IR.Type] = []
  for i = 0; i < 8; i = i + 1 {
    callee_types.push(i32ty)
  }
  let callee_fty = ctx.getFunctionType(i32ty, callee_types)
  let callee_func = mod.addFunction(callee_fty, "callee")
  
  let call_args : Array[&@IR.Value] = []
  for i = 1; i <= 8; i = i + 1 {
    call_args.push(ctx.getConstInt32(i))
  }
  
  let result = builder.createCall(callee_func, call_args)
  let _ = builder.createRet(result)
  
  // Convert to MIR
  let mir_func = @GMIR.Function::from_llvm_function(caller_func)
  
  // Legalize with only 4 registers available
  let config = @GMIR.LegalizeConfig::{
    max_num_call_regs: 4,
    max_num_call_fregs: 4
  }
  let legalized_func = @GMIR.legalize_func(mir_func, config)
  
  // Verify that spill code was generated
  let mut store_count = 0
  let mut has_call = false
  let mut mem_args = 0
  
  for bb in legalized_func.body {
    for inst in bb.insts {
      match inst.opcode {
        @GMIR.Storeq => store_count += 1
        @GMIR.Call => {
          has_call = true
          // Count memory operands in the call
          for use_op in inst.uses {
            match use_op {
              @GMIR.Mem(_, _) => mem_args += 1
              _ => ()
            }
          }
        }
        _ => ()
      }
    }
  }
  
  // We expect 4 arguments to be spilled (args 5-8)
  assert_eq(store_count, 4)
  assert_eq(has_call, true)
  assert_eq(mem_args, 4)
}

test "legalize_mixed_type_call" {
  // Test with mixed integer and float arguments
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("test")
  let i32ty = ctx.getInt32Ty()
  let f64ty = ctx.getDoubleTy()
  
  let caller_fty = ctx.getFunctionType(i32ty, [])
  let caller_func = mod.addFunction(caller_fty, "caller")
  let bb = caller_func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  
  // Create a call with alternating int and float arguments (6 of each)
  let callee_types : Array[&@IR.Type] = []
  let call_args : Array[&@IR.Value] = []
  for i = 0; i < 12; i = i + 1 {
    if i % 2 == 0 {
      callee_types.push(i32ty)
      call_args.push(ctx.getConstInt32(i))
    } else {
      callee_types.push(f64ty)
      call_args.push(ctx.getConstDouble(i.to_double()))
    }
  }
  
  let callee_fty = ctx.getFunctionType(i32ty, callee_types)
  let callee_func = mod.addFunction(callee_fty, "mixed_callee")
  
  let result = builder.createCall(callee_func, call_args)
  let _ = builder.createRet(result)
  
  // Convert to MIR
  let mir_func = @GMIR.Function::from_llvm_function(caller_func)
  
  // Legalize with only 3 registers of each type
  let config = @GMIR.LegalizeConfig::{
    max_num_call_regs: 3,
    max_num_call_fregs: 3
  }
  let legalized_func = @GMIR.legalize_func(mir_func, config)
  
  // Count spills by type
  let mut int_stores = 0
  let mut float_stores = 0
  
  for bb in legalized_func.body {
    for inst in bb.insts {
      match inst.opcode {
        @GMIR.Storeq => int_stores += 1
        @GMIR.FStoreD => float_stores += 1
        _ => ()
      }
    }
  }
  
  // We expect 3 int spills (args 7, 9, 11) and 3 float spills (args 8, 10, 12)
  assert_eq(int_stores, 3)
  assert_eq(float_stores, 3)
}

test "legalize_no_spill_needed" {
  // Test that functions with few arguments don't generate unnecessary spills
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("test")
  let i32ty = ctx.getInt32Ty()
  
  let caller_fty = ctx.getFunctionType(i32ty, [])
  let caller_func = mod.addFunction(caller_fty, "caller")
  let bb = caller_func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  
  // Create a call with only 2 arguments
  let callee_fty = ctx.getFunctionType(i32ty, [i32ty, i32ty])
  let callee_func = mod.addFunction(callee_fty, "simple_callee")
  
  let arg1 = ctx.getConstInt32(10)
  let arg2 = ctx.getConstInt32(20)
  let result = builder.createCall(callee_func, [arg1, arg2])
  let _ = builder.createRet(result)
  
  // Convert to MIR
  let mir_func = @GMIR.Function::from_llvm_function(caller_func)
  
  // Legalize with plenty of registers
  let config = @GMIR.LegalizeConfig::{
    max_num_call_regs: 8,
    max_num_call_fregs: 8
  }
  let legalized_func = @GMIR.legalize_func(mir_func, config)
  
  // Verify no spill code was generated
  let mut store_count = 0
  for bb in legalized_func.body {
    for inst in bb.insts {
      match inst.opcode {
        @GMIR.Storeq | @GMIR.FStoreD => store_count += 1
        _ => ()
      }
    }
  }
  
  assert_eq(store_count, 0)
}

test "legalize_function_params_structure" {
  // Test that function parameter structure is maintained correctly
  let ctx = @IR.Context::new()
  let mod = ctx.addModule("test")
  let i32ty = ctx.getInt32Ty()
  
  // Create a function with 6 parameters
  let param_types : Array[&@IR.Type] = []
  for i = 0; i < 6; i = i + 1 {
    param_types.push(i32ty)
  }
  
  let fty = ctx.getFunctionType(i32ty, param_types)
  let func = mod.addFunction(fty, "six_params")
  let bb = func.addBasicBlock(name="entry")
  let builder = ctx.createBuilder()
  builder.setInsertPoint(bb)
  
  // Use all parameters - sum them and return
  let mut sum : &@IR.Value = func.getArg(0).unwrap()
  for i = 1; i < 6; i = i + 1 {
    let arg : &@IR.Value = func.getArg(i).unwrap()
    sum = builder.createAdd(sum, arg)
  }
  let _ = builder.createRet(sum)
  
  // Convert to MIR
  let mir_func = @GMIR.Function::from_llvm_function(func)
  
  // Legalize with only 4 registers
  let config = @GMIR.LegalizeConfig::{
    max_num_call_regs: 4,
    max_num_call_fregs: 4
  }
  let legalized_func = @GMIR.legalize_func(mir_func, config)
  
  // Check that the function still has 6 parameters
  assert_eq(legalized_func.params.length(), 6)
  
  // Check that parameters 5 and 6 are now Mem operands
  let mut mem_param_count = 0
  let mut vreg_param_count = 0
  for param in legalized_func.params {
    match param {
      @GMIR.Mem(_, _) => mem_param_count += 1
      @GMIR.VReg(_) => vreg_param_count += 1
      _ => ()
    }
  }
  
  // First 4 parameters should be VReg, last 2 should be Mem
  assert_eq(vreg_param_count, 4)
  assert_eq(mem_param_count, 2)
}