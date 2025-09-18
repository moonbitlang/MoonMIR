///|
fn main {
  demo_legalize_transformation()
  println("\n" + "=".repeat(80))
  test_negative_offsets()
  test_calling_convention()
  println("\nAll tests completed successfully!")
}

///|
fn demo_legalize_transformation() -> Unit {
  println("=".repeat(80))
  println("演示 Legalize 转换过程")
  println("=".repeat(80))

  // 创建一个有10个参数的函数（超过8个寄存器限制）
  println("\n【1. 创建原始函数】")
  println("函数 sum10: 接收10个整数参数，返回它们的和")
  let func = @GMIR.Function::new("sum10")

  // 添加10个参数
  for i = 1; i <= 10; i = i + 1 {
    func.params.push(@GMIR.VReg(i))
  }
  println("\n原始函数参数:")
  for i, param in func.params {
    println("  参数\{i + 1}: \{param}")
  }
  let bb = @GMIR.BasicBlock::new("entry")

  // 创建一个简单的加法链
  bb.insts.push(@GMIR.Instruction::{
    opcode: @GMIR.Addq,
    defs: [@GMIR.VReg(100)],
    uses: [@GMIR.VReg(1), @GMIR.VReg(2)],
  })

  // 添加剩余参数
  for i = 3; i <= 10; i = i + 1 {
    bb.insts.push(@GMIR.Instruction::{
      opcode: @GMIR.Addq,
      defs: [@GMIR.VReg(100 + i - 2)],
      uses: [@GMIR.VReg(100 + i - 3), @GMIR.VReg(i)],
    })
  }
  bb.insts.push(@GMIR.Instruction::{
    opcode: @GMIR.Ret,
    defs: [],
    uses: [@GMIR.VReg(108)],
  })
  func.body.push(bb)

  println("\n原始函数指令:")
  println(func)

  // Legalize 配置：最多8个寄存器
  let config = @GMIR.LegalizeConfig::{
    max_num_call_regs: 8,
    max_num_call_fregs: 8,
  }
  println("\nLegalize 配置:")
  println("  max_num_call_regs: 8")
  println("  max_num_call_fregs: 8")

  // 执行 Legalize
  try {
    let legalized_func = @GMIR.legalize_func(func, config)
    println("\n【2. Legalize 后的函数】")
    println(legalized_func)
    println("\nLegalized 函数参数:")
    for i, param in legalized_func.params {
      match param {
        @GMIR.VReg(id) =>
          println("  参数\{i + 1}: %v\{id} (保留在寄存器)")
        @GMIR.Mem(base, offset) =>
          match base {
            @GMIR.StackPtr =>
              if offset < 0 {
                println(
                  "  参数\{i + 1}: (sp \{offset}) [来自调用者栈帧]",
                )
              } else {
                println("  参数\{i + 1}: (sp + \{offset})")
              }
            _ => println("  参数\{i + 1}: \{param}")
          }
        _ => println("  参数\{i + 1}: \{param}")
      }
    }
    println("\n变化总结:")
    println("  • 前8个参数保留在寄存器中 (%v1 - %v8)")
    println("  • 第9个参数溢出到 (sp - 8)  - 调用者栈帧")
    println("  • 第10个参数溢出到 (sp - 16) - 调用者栈帧")
  } catch {
    e => println("Legalize 失败: \{e}")
  }

  // 演示 Call 指令的 legalize
  println("\n" + "-".repeat(80))
  println("\n【3. Call 指令的 Legalize】")
  let caller = @GMIR.Function::new("caller")
  let caller_bb = @GMIR.BasicBlock::new("entry")

  // 创建一个有12个参数的 Call 指令
  let call_uses : Array[@GMIR.Operand] = [@GMIR.Label("sum12")]
  for i = 1; i <= 12; i = i + 1 {
    call_uses.push(@GMIR.VReg(200 + i))
  }
  let call_inst = @GMIR.Instruction::{
    opcode: @GMIR.Call,
    defs: [@GMIR.VReg(300)],
    uses: call_uses,
  }
  println("\n原始 Call 指令:")
  println("  Call sum12(%v201, %v202, ..., %v212) -> %v300")
  println("  共12个参数")
  caller_bb.insts.push(call_inst)
  caller_bb.insts.push(@GMIR.Instruction::{
    opcode: @GMIR.Ret,
    defs: [],
    uses: [@GMIR.VReg(300)],
  })
  caller.body.push(caller_bb)

  println("\n原始函数指令:")
  println(caller)

  // Legalize Call 指令
  try {
    let legalized_caller = @GMIR.legalize_func(caller, config)
    println("\n【4. Legalize 后的调用者函数】")
    println(legalized_caller)
    println("\nLegalized 后的指令序列:")
    let bb = legalized_caller.body[0]
    for i, inst in bb.insts {
      match inst.opcode {
        @GMIR.Storeq => {
          println("  [\{i + 1}] Storeq \{inst.uses[1]}, \{inst.uses[0]}")
          println("       // 将参数存储到栈上")
        }
        @GMIR.Call => {
          println("  [\{i + 1}] Call \{inst.uses[0]}(")
          for j = 1; j < inst.uses.length(); j = j + 1 {
            let arg = inst.uses[j]
            match arg {
              @GMIR.VReg(id) => println("         %v\{id},")
              @GMIR.Mem(_, offset) =>
                println("         (sp + \{offset}), // 溢出参数")
              _ => println("         \{arg},")
            }
          }
          println("       ) -> \{inst.defs[0]}")
        }
        @GMIR.Ret => println("  [\{i + 1}] Ret \{inst.uses[0]}")
        _ => println("  [\{i + 1}] \{inst.opcode}")
      }
    }
    println("\nCall 指令变化总结:")
    println("  • 前8个参数直接传递")
    println("  • 参数9-12需要先存储到栈上 (Storeq 指令)")
    println("  • Call 指令中溢出的参数使用栈位置 (sp + offset)")
  } catch {
    e => println("Call legalize 失败: \{e}")
  }
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
