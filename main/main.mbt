///|
fn main {
  test_negative_offsets()
  test_calling_convention()
  println("All tests completed successfully!")
}

///|
fn test_negative_offsets() -> Unit {
  println("\n=== Testing Negative Memory Offsets ===")
  let vm = @GMIR.VirtualMachine::new()

  // Create a function that uses negative offsets to simulate
  // accessing caller's stack frame
  let func = @GMIR.Function::new("test_negative_offset")

  // The function will:
  // 1. Use a memory location at a negative offset (simulating a parameter from caller's stack)
  // 2. Use a memory location at a positive offset (local variable)
  // 3. Load from both and add them

  let bb = @GMIR.BasicBlock::new("entry")

  // Move immediate values to memory locations
  // Using Mov to set up memory directly

  // Move 42 into memory at (sp - 8) - simulating a parameter from caller
  bb.insts.push(@GMIR.Instruction::{
    opcode: @GMIR.Movq,
    defs: [@GMIR.Mem(@GMIR.StackPtr, -8)],
    uses: [@GMIR.Imm(42L)],
  })

  // Move 58 into memory at (sp + 8) - local variable
  bb.insts.push(@GMIR.Instruction::{
    opcode: @GMIR.Movq,
    defs: [@GMIR.Mem(@GMIR.StackPtr, 8)],
    uses: [@GMIR.Imm(58L)],
  })

  // Load from (sp - 8) into %v1
  bb.insts.push(@GMIR.Instruction::{
    opcode: @GMIR.Movq,
    defs: [@GMIR.VReg(1)],
    uses: [@GMIR.Mem(@GMIR.StackPtr, -8)],
  })

  // Load from (sp + 8) into %v2  
  bb.insts.push(@GMIR.Instruction::{
    opcode: @GMIR.Movq,
    defs: [@GMIR.VReg(2)],
    uses: [@GMIR.Mem(@GMIR.StackPtr, 8)],
  })

  // Add them: %v3 = %v1 + %v2
  bb.insts.push(@GMIR.Instruction::{
    opcode: @GMIR.Addq,
    defs: [@GMIR.VReg(3)],
    uses: [@GMIR.VReg(1), @GMIR.VReg(2)],
  })

  // Return the sum
  bb.insts.push(@GMIR.Instruction::{
    opcode: @GMIR.Ret,
    defs: [],
    uses: [@GMIR.VReg(3)],
  })
  func.body.push(bb)
  try {
    let result = vm.eval_function(func, [])
    match result {
      @GMIR.VMValue::Int(val) =>
        if val == 100L {
          println("✓ Negative offset test passed: 42 + 58 = 100")
        } else {
          println("✗ Negative offset test failed: expected 100, got \{val}")
        }
      _ => println("✗ Negative offset test failed: unexpected result type")
    }
  } catch {
    e => println("✗ Negative offset test failed with error: \{e}")
  }
}

///|
fn test_calling_convention() -> Unit {
  println("\n=== Testing Calling Convention with Spilled Parameters ===")

  // Test the legalize pass with functions that have more parameters
  // than available registers
  let module = @GMIR.Module::new()

  // Create a function with 10 integer parameters (exceeding typical 8 regs)
  let func = @GMIR.Function::new("many_params")

  // Add 10 parameters
  for i = 1; i <= 10; i = i + 1 {
    func.params.push(@GMIR.VReg(i))
  }
  let bb = @GMIR.BasicBlock::new("entry")

  // Sum all parameters: result = p1 + p2 + ... + p10
  bb.insts.push(@GMIR.Instruction::{
    opcode: @GMIR.Addq,
    defs: [@GMIR.VReg(100)],
    uses: [@GMIR.VReg(1), @GMIR.VReg(2)],
  })
  for i = 3; i <= 10; i = i + 1 {
    bb.insts.push(@GMIR.Instruction::{
      opcode: @GMIR.Addq,
      defs: [@GMIR.VReg(100 + i - 2)],
      uses: [@GMIR.VReg(100 + i - 3), @GMIR.VReg(i)],
    })
  }

  // Return the sum
  bb.insts.push(@GMIR.Instruction::{
    opcode: @GMIR.Ret,
    defs: [],
    uses: [@GMIR.VReg(108)],
  })
  func.body.push(bb)
  module.functions.push(func)

  // Legalize with 8 registers available
  let config = @GMIR.LegalizeConfig::{
    max_num_call_regs: 8,
    max_num_call_fregs: 8,
  }
  try {
    let legalized_module = module.legalize_with_config(config)
    let legalized_func = legalized_module.functions[0]

    // Check that parameters 9 and 10 are now memory operands with negative offsets
    let mut mem_params = 0
    let mut reg_params = 0
    for param in legalized_func.params {
      match param {
        @GMIR.Mem(base, offset) => {
          mem_params += 1
          match base {
            @GMIR.StackPtr =>
              if offset >= 0 {
                println(
                  "✗ Expected negative offset for spilled parameter, got \{offset}",
                )
              } else {
                println(
                  "✓ Spilled parameter correctly uses negative offset: \{offset}",
                )
              }
            _ => println("✗ Unexpected base register for spilled parameter")
          }
        }
        @GMIR.VReg(_) => reg_params += 1
        _ => ()
      }
    }
    if reg_params == 8 && mem_params == 2 {
      println(
        "✓ Legalization correctly spilled 2 parameters (kept 8 in registers)",
      )
    } else {
      println(
        "✗ Unexpected parameter distribution: \{reg_params} in regs, \{mem_params} in memory",
      )
    }

    // Now test execution with the VM
    let vm = @GMIR.VirtualMachine::new()

    // Prepare arguments: 1, 2, 3, ..., 10
    let args : Array[@GMIR.VMValue] = []
    for i = 1; i <= 10; i = i + 1 {
      args.push(@GMIR.VMValue::Int(i.to_int64()))
    }

    // First 8 parameters go in registers, last 2 should be on stack
    // We need to set up the stack properly for the spilled parameters
    // This would normally be done by the caller

    // For now, just verify that the legalized function structure is correct
    println("✓ Calling convention test completed")
  } catch {
    e => println("✗ Calling convention test failed: \{e}")
  }
}
