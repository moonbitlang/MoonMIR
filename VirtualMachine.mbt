///|
/// VMValue represents values that can be stored and manipulated in the VM
pub enum VMValue {
  Int(Int64)
  Double(Double)
  Address(Int64) // Memory addresses
  Void
} derive(Show, Eq)

///|
/// VM error types
pub suberror VMError {
  // Errors related to unreasonable operations,
  // for example, call a unknown function, or use
  // a undefined register.
  IRError(String)

  // Errors related to runtime issues,
  // for example, divide by zero, or overflow.
  RuntimeError(String)
} derive(Show)

///|
/// Execution context for a function call
pub struct ExecutionContext {
  // Virtual register files
  mut vregs : Map[Int, VMValue]
  mut vfregs : Map[Int, VMValue]

  // Physical register files (if needed after register allocation)
  mut regs : Map[Int, VMValue]
  mut fregs : Map[Int, VMValue]

  // Current basic block index and instruction index
  mut current_bb : Int
  mut current_inst : Int

  // Stack for local variables and spilled registers
  mut stack : Array[VMValue]
  mut stack_ptr : Int

  // Function being executed
  function : Function
}

///|
fn ExecutionContext::new(
  func : Function,
  args : Array[VMValue],
) -> ExecutionContext raise VMError {
  let ctx = ExecutionContext::{
    vregs: Map::new(),
    vfregs: Map::new(),
    regs: Map::new(),
    fregs: Map::new(),
    current_bb: 0,
    current_inst: 0,
    stack: Array::new(),
    stack_ptr: 0,
    function: func,
  }

  // Initialize stack with sufficient space
  for i = 0; i < 100; i = i + 1 {
    ctx.stack.push(VMValue::Int(0L))
  }

  // Initialize function parameters
  for i = 0; i < func.params.length() && i < args.length(); i = i + 1 {
    ctx.set_operand_value(func.params[i], args[i])
  }
  ctx
}

///|
fn ExecutionContext::get_operand_value(
  self : ExecutionContext,
  op : Operand,
) -> VMValue raise VMError {
  match op {
    VReg(id) =>
      match self.vregs.get(id) {
        Some(val) => val
        None => raise VMError::IRError("Undefined virtual register %v\{id}")
      }
    VFReg(id) =>
      match self.vfregs.get(id) {
        Some(val) => val
        None =>
          raise VMError::IRError("Undefined virtual float register %vf\{id}")
      }
    Reg(id) =>
      match self.regs.get(id) {
        Some(val) => val
        None => raise VMError::IRError("Undefined physical register %r\{id}")
      }
    FReg(id) =>
      match self.fregs.get(id) {
        Some(val) => val
        None =>
          raise VMError::IRError("Undefined physical float register %f\{id}")
      }
    Imm(val) => VMValue::Int(val)
    FImm(val) => VMValue::Double(val)
    Mem(base, offset) => {
      let base_val = self.get_operand_value(base)
      let addr = match base_val {
        VMValue::Int(base_addr) => base_addr + offset.to_int64()
        VMValue::Address(base_addr) => base_addr + offset.to_int64()
        _ =>
          raise VMError::RuntimeError(
            "Invalid base address for memory operation",
          )
      }
      // For now, simulate memory as stack access
      let stack_idx = addr.to_int()
      if stack_idx < 0 || stack_idx >= self.stack.length() {
        raise VMError::RuntimeError("Memory access out of bounds")
      }
      self.stack[stack_idx]
    }
    Label(_) => raise VMError::IRError("Cannot get value of label operand")
    StackTop => VMValue::Address(self.stack_ptr.to_int64())
  }
}

///|
fn ExecutionContext::set_operand_value(
  self : ExecutionContext,
  op : Operand,
  val : VMValue,
) -> Unit raise VMError {
  match op {
    VReg(id) => self.vregs[id] = val
    VFReg(id) => self.vfregs[id] = val
    Reg(id) => self.regs[id] = val
    FReg(id) => self.fregs[id] = val
    Mem(base, offset) => {
      let base_val = self.get_operand_value(base)
      let addr = match base_val {
        VMValue::Int(base_addr) => base_addr + offset.to_int64()
        VMValue::Address(base_addr) => base_addr + offset.to_int64()
        _ =>
          raise VMError::RuntimeError(
            "Invalid base address for memory operation",
          )
      }
      let stack_idx = addr.to_int()
      if stack_idx < 0 || stack_idx >= self.stack.length() {
        raise VMError::RuntimeError("Memory access out of bounds")
      }
      self.stack[stack_idx] = val
    }
    _ => raise VMError::IRError("Cannot set value to this operand type")
  }
}

///|
fn ExecutionContext::find_bb_by_label(
  self : ExecutionContext,
  label : String,
) -> Int raise VMError {
  for i = 0; i < self.function.body.length(); i = i + 1 {
    if self.function.body[i].label == label {
      return i
    }
  }
  raise VMError::IRError("Basic block with label '\{label}' not found")
}

///|
/// Virtual Machine implementation
pub struct VirtualMachine {
  external_functions : Map[String, (Array[VMValue]) -> VMValue raise VMError]
  mut memory : Array[VMValue] // Global memory simulation
}

///|
pub fn VirtualMachine::new() -> VirtualMachine {
  fn print_int(args : Array[VMValue]) -> VMValue raise VMError {
    if args.length() < 1 {
      raise VMError::RuntimeError("print_int expects at least 1 argument")
    }
    match args[0] {
      VMValue::Int(i) => println(i)
      _ => raise VMError::RuntimeError("print_int expects an integer argument")
    }
    VMValue::Void
  }

  fn print_double(args : Array[VMValue]) -> VMValue raise VMError {
    if args.length() < 1 {
      raise VMError::RuntimeError("print_double expects at least 1 argument")
    }
    match args[0] {
      VMValue::Double(d) => println(d)
      _ => raise VMError::RuntimeError("print_double expects a double argument")
    }
    VMValue::Void
  }

  let external_functions : Map[
    String,
    (Array[VMValue]) -> VMValue raise VMError,
  ] = { "print_int": print_int, "print_double": print_double }
  let memory = Array::new()
  // Initialize with some memory space
  for i = 0; i < 1000; i = i + 1 {
    memory.push(VMValue::Int(0L))
  }
  VirtualMachine::{ external_functions, memory }
}

///|
/// Execute an instruction in the given context
fn VirtualMachine::execute_instruction(
  self : VirtualMachine,
  ctx : ExecutionContext,
  inst : Instruction,
) -> Bool raise VMError {
  match inst.opcode {
    // Arithmetic operations
    Addq => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) => VMValue::Int(a + b)
        _ => raise VMError::RuntimeError("Invalid operands for Addq")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Add(bits) => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) => {
          let sum = a + b
          // Mask to specified bit width
          let shift_amount = if bits > 63 { 63 } else { bits }
          let mask = (1L << shift_amount) - 1L
          VMValue::Int(sum & mask)
        }
        _ => raise VMError::RuntimeError("Invalid operands for Add")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Subq => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) => VMValue::Int(a - b)
        _ => raise VMError::RuntimeError("Invalid operands for Subq")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Sub(bits) => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) => {
          let diff = a - b
          let shift_amount = if bits > 63 { 63 } else { bits }
          let mask = (1L << shift_amount) - 1L
          VMValue::Int(diff & mask)
        }
        _ => raise VMError::RuntimeError("Invalid operands for Sub")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Mulq => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) => VMValue::Int(a * b)
        _ => raise VMError::RuntimeError("Invalid operands for Mulq")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Mul(bits) => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) => {
          let prod = a * b
          let shift_amount = if bits > 63 { 63 } else { bits }
          let mask = (1L << shift_amount) - 1L
          VMValue::Int(prod & mask)
        }
        _ => raise VMError::RuntimeError("Invalid operands for Mul")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Divq => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) => {
          if b == 0L {
            raise VMError::RuntimeError("Division by zero")
          }
          VMValue::Int(a / b)
        }
        _ => raise VMError::RuntimeError("Invalid operands for Divq")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Div(bits) => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) => {
          if b == 0L {
            raise VMError::RuntimeError("Division by zero")
          }
          let quot = a / b
          let shift_amount = if bits > 63 { 63 } else { bits }
          let mask = (1L << shift_amount) - 1L
          VMValue::Int(quot & mask)
        }
        _ => raise VMError::RuntimeError("Invalid operands for Div")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }

    // Floating point operations
    FAddD => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Double(a), VMValue::Double(b)) => VMValue::Double(a + b)
        _ => raise VMError::RuntimeError("Invalid operands for FAddD")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    FSubD => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Double(a), VMValue::Double(b)) => VMValue::Double(a - b)
        _ => raise VMError::RuntimeError("Invalid operands for FSubD")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    FMulD => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Double(a), VMValue::Double(b)) => VMValue::Double(a * b)
        _ => raise VMError::RuntimeError("Invalid operands for FMulD")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    FDivD => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Double(a), VMValue::Double(b)) => {
          if b == 0.0 {
            raise VMError::RuntimeError("Division by zero")
          }
          VMValue::Double(a / b)
        }
        _ => raise VMError::RuntimeError("Invalid operands for FDivD")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }

    // Move operations
    Movq => {
      let val = ctx.get_operand_value(inst.uses[0])
      ctx.set_operand_value(inst.defs[0], val)
      false
    }
    Mov(bits) => {
      let val = ctx.get_operand_value(inst.uses[0])
      let masked_val = match val {
        VMValue::Int(i) => {
          let shift_amount = if bits > 63 { 63 } else { bits }
          let mask = (1L << shift_amount) - 1L
          VMValue::Int(i & mask)
        }
        _ => val
      }
      ctx.set_operand_value(inst.defs[0], masked_val)
      false
    }
    FMovD => {
      let val = ctx.get_operand_value(inst.uses[0])
      ctx.set_operand_value(inst.defs[0], val)
      false
    }

    // Load operations
    Loadq => {
      let addr_val = ctx.get_operand_value(inst.uses[0])
      let addr = match addr_val {
        VMValue::Int(a) => a.to_int()
        VMValue::Address(a) => a.to_int()
        _ => raise VMError::RuntimeError("Invalid address for load")
      }
      if addr < 0 || addr >= self.memory.length() {
        raise VMError::RuntimeError("Memory access out of bounds")
      }
      ctx.set_operand_value(inst.defs[0], self.memory[addr])
      false
    }
    Load(bits) => {
      let addr_val = ctx.get_operand_value(inst.uses[0])
      let addr = match addr_val {
        VMValue::Int(a) => a.to_int()
        VMValue::Address(a) => a.to_int()
        _ => raise VMError::RuntimeError("Invalid address for load")
      }
      if addr < 0 || addr >= self.memory.length() {
        raise VMError::RuntimeError("Memory access out of bounds")
      }
      let val = self.memory[addr]
      let masked_val = match val {
        VMValue::Int(i) => {
          let shift_amount = if bits > 63 { 63 } else { bits }
          let mask = (1L << shift_amount) - 1L
          VMValue::Int(i & mask)
        }
        _ => val
      }
      ctx.set_operand_value(inst.defs[0], masked_val)
      false
    }

    // Store operations
    Storeq => {
      let val = ctx.get_operand_value(inst.uses[0])
      let addr_val = ctx.get_operand_value(inst.uses[1])
      let addr = match addr_val {
        VMValue::Int(a) => a.to_int()
        VMValue::Address(a) => a.to_int()
        _ => raise VMError::RuntimeError("Invalid address for store")
      }
      if addr < 0 || addr >= self.memory.length() {
        raise VMError::RuntimeError("Memory access out of bounds")
      }
      self.memory[addr] = val
      false
    }
    Store(bits) => {
      let val = ctx.get_operand_value(inst.uses[0])
      let addr_val = ctx.get_operand_value(inst.uses[1])
      let addr = match addr_val {
        VMValue::Int(a) => a.to_int()
        VMValue::Address(a) => a.to_int()
        _ => raise VMError::RuntimeError("Invalid address for store")
      }
      if addr < 0 || addr >= self.memory.length() {
        raise VMError::RuntimeError("Memory access out of bounds")
      }
      let masked_val = match val {
        VMValue::Int(i) => {
          let shift_amount = if bits > 63 { 63 } else { bits }
          let mask = (1L << shift_amount) - 1L
          VMValue::Int(i & mask)
        }
        _ => val
      }
      self.memory[addr] = masked_val
      false
    }

    // Comparison operations
    Eq => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) =>
          VMValue::Int(if a == b { 1L } else { 0L })
        (VMValue::Double(a), VMValue::Double(b)) =>
          VMValue::Int(if a == b { 1L } else { 0L })
        _ => raise VMError::RuntimeError("Invalid operands for Eq")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Ne => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) =>
          VMValue::Int(if a != b { 1L } else { 0L })
        (VMValue::Double(a), VMValue::Double(b)) =>
          VMValue::Int(if a != b { 1L } else { 0L })
        _ => raise VMError::RuntimeError("Invalid operands for Ne")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Lt => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) =>
          VMValue::Int(if a < b { 1L } else { 0L })
        (VMValue::Double(a), VMValue::Double(b)) =>
          VMValue::Int(if a < b { 1L } else { 0L })
        _ => raise VMError::RuntimeError("Invalid operands for Lt")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Le => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) =>
          VMValue::Int(if a <= b { 1L } else { 0L })
        (VMValue::Double(a), VMValue::Double(b)) =>
          VMValue::Int(if a <= b { 1L } else { 0L })
        _ => raise VMError::RuntimeError("Invalid operands for Le")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Gt => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) =>
          VMValue::Int(if a > b { 1L } else { 0L })
        (VMValue::Double(a), VMValue::Double(b)) =>
          VMValue::Int(if a > b { 1L } else { 0L })
        _ => raise VMError::RuntimeError("Invalid operands for Gt")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }
    Ge => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let result = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) =>
          VMValue::Int(if a >= b { 1L } else { 0L })
        (VMValue::Double(a), VMValue::Double(b)) =>
          VMValue::Int(if a >= b { 1L } else { 0L })
        _ => raise VMError::RuntimeError("Invalid operands for Ge")
      }
      ctx.set_operand_value(inst.defs[0], result)
      false
    }

    // Branch operations
    Beq => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let should_branch = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) => a == b
        (VMValue::Double(a), VMValue::Double(b)) => a == b
        _ => raise VMError::RuntimeError("Invalid operands for Beq")
      }
      if should_branch {
        let target_label = match inst.uses[2] {
          Label(label) => label
          _ => raise VMError::IRError("Expected label for branch target")
        }
        ctx.current_bb = ctx.find_bb_by_label(target_label)
        ctx.current_inst = 0
        true // Branch taken - this is a terminator
      } else {
        false // Branch not taken - continue to next instruction
      }
    }
    Bne => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let should_branch = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) => a != b
        (VMValue::Double(a), VMValue::Double(b)) => a != b
        _ => raise VMError::RuntimeError("Invalid operands for Bne")
      }
      if should_branch {
        let target_label = match inst.uses[2] {
          Label(label) => label
          _ => raise VMError::IRError("Expected label for branch target")
        }
        ctx.current_bb = ctx.find_bb_by_label(target_label)
        ctx.current_inst = 0
        true // Branch taken - this is a terminator
      } else {
        false // Branch not taken - continue to next instruction
      }
    }
    Blt => {
      let val1 = ctx.get_operand_value(inst.uses[0])
      let val2 = ctx.get_operand_value(inst.uses[1])
      let should_branch = match (val1, val2) {
        (VMValue::Int(a), VMValue::Int(b)) => a < b
        (VMValue::Double(a), VMValue::Double(b)) => a < b
        _ => raise VMError::RuntimeError("Invalid operands for Blt")
      }
      if should_branch {
        let target_label = match inst.uses[2] {
          Label(label) => label
          _ => raise VMError::IRError("Expected label for branch target")
        }
        ctx.current_bb = ctx.find_bb_by_label(target_label)
        ctx.current_inst = 0
        true // Branch taken - this is a terminator
      } else {
        false // Branch not taken - continue to next instruction
      }
    }
    Jmp => {
      let target_label = match inst.uses[0] {
        Label(label) => label
        _ => raise VMError::IRError("Expected label for jump target")
      }
      ctx.current_bb = ctx.find_bb_by_label(target_label)
      ctx.current_inst = 0
      true // This is a terminator
    }

    // Function call
    Call => {
      let func_name = match inst.uses[0] {
        Label(name) => name
        _ => raise VMError::IRError("Expected label for function call")
      }

      // Collect arguments (skip the function name)
      let args = Array::new()
      for i = 1; i < inst.uses.length(); i = i + 1 {
        args.push(ctx.get_operand_value(inst.uses[i]))
      }

      // Call external function
      match self.external_functions.get(func_name) {
        Some(func) => {
          let result = func(args)
          if inst.defs.length() > 0 {
            ctx.set_operand_value(inst.defs[0], result)
          }
        }
        None => raise VMError::IRError("Unknown function: \{func_name}")
      }
      false
    }

    // Return
    Ret =>
      // Will be handled by the main execution loop
      true

    // No-op
    Nop => false

    // PHI instruction (should be eliminated before execution)
    PHI =>
      raise VMError::IRError(
        "PHI instruction should be eliminated before execution",
      )

    // Type conversion instructions
    ZExt => {
      let val = ctx.get_operand_value(inst.uses[0])
      match val {
        VMValue::Int(i) => ctx.set_operand_value(inst.defs[0], VMValue::Int(i))
        _ => raise VMError::RuntimeError("Invalid operand for ZExt")
      }
      false
    }
    SExt => {
      let val = ctx.get_operand_value(inst.uses[0])
      match val {
        VMValue::Int(i) => ctx.set_operand_value(inst.defs[0], VMValue::Int(i))
        _ => raise VMError::RuntimeError("Invalid operand for SExt")
      }
      false
    }
    SIToFP(from_bits, to_bits) => {
      let val = ctx.get_operand_value(inst.uses[0])
      match val {
        VMValue::Int(i) => {
          let result = VMValue::Double(i.to_double())
          ctx.set_operand_value(inst.defs[0], result)
        }
        _ => raise VMError::RuntimeError("Invalid operand for SIToFP")
      }
      false
    }
    FPToSI(from_bits, to_bits) => {
      let val = ctx.get_operand_value(inst.uses[0])
      match val {
        VMValue::Double(d) => {
          let result = VMValue::Int(d.to_int64())
          ctx.set_operand_value(inst.defs[0], result)
        }
        _ => raise VMError::RuntimeError("Invalid operand for FPToSI")
      }
      false
    }

    // Other opcodes can be added as needed
    _ => raise VMError::IRError("Unimplemented opcode: \{inst.opcode}")
  }
}

///|
/// Execute a module (run the main function if it exists)
pub fn VirtualMachine::eval_module(
  self : Self,
  mod : Module,
) -> Unit raise VMError {
  // Look for main function
  let mut main_func : Function? = None
  for func in mod.functions {
    if func.name == "main" {
      main_func = Some(func)
      break
    }
  }
  match main_func {
    Some(func) => ignore(self.eval_function(func, []))
    None => raise VMError::IRError("No main function found in module")
  }
}

///|
/// Execute a function with given arguments
pub fn VirtualMachine::eval_function(
  self : Self,
  func : Function,
  args : Array[VMValue],
) -> VMValue raise VMError {
  if func.body.length() == 0 {
    return VMValue::Void
  }
  let ctx = ExecutionContext::new(func, args)
  let mut step_count = 0
  let max_steps = 1000 // Prevent infinite loops

  // Main execution loop
  while step_count < max_steps {
    step_count = step_count + 1
    if ctx.current_bb >= func.body.length() {
      // Reached end of function
      break VMValue::Void
    }
    let bb = func.body[ctx.current_bb]
    if ctx.current_inst >= bb.insts.length() {
      // Reached end of basic block without terminator
      ctx.current_bb = ctx.current_bb + 1
      ctx.current_inst = 0
      continue
    }
    let inst = bb.insts[ctx.current_inst]

    // Check for return instruction
    if inst.opcode is Ret {
      if inst.uses.length() > 0 {
        break ctx.get_operand_value(inst.uses[0])
      } else {
        break VMValue::Void
      }
    }
    let is_terminator = self.execute_instruction(ctx, inst)
    if is_terminator {
      // Terminator was executed, continue from new position
      continue
    } else {
      // Move to next instruction
      ctx.current_inst = ctx.current_inst + 1
    }
  } else {
    raise VMError::RuntimeError(
      "Function execution exceeded maximum steps (\{max_steps})",
    )
  }
}

///|
test "simple arithmetic" {
  let vm = VirtualMachine::new()

  // Create a simple function that adds two numbers
  let func = Function::new("test_add")
  func.params.push(VReg(1))
  func.params.push(VReg(2))
  let bb = BasicBlock::new("entry")
  bb.insts.push(Instruction::{
    opcode: Addq,
    defs: [VReg(3)],
    uses: [VReg(1), VReg(2)],
  })
  bb.insts.push(Instruction::{ opcode: Ret, defs: [], uses: [VReg(3)] })
  func.body.push(bb)
  let result = vm.eval_function(func, [VMValue::Int(10L), VMValue::Int(20L)])
  inspect(result, content="Int(30)")
}

///|
test "floating point operations" {
  let vm = VirtualMachine::new()
  let func = Function::new("test_fadd")
  func.params.push(VFReg(1))
  func.params.push(VFReg(2))
  let bb = BasicBlock::new("entry")
  bb.insts.push(Instruction::{
    opcode: FAddD,
    defs: [VFReg(3)],
    uses: [VFReg(1), VFReg(2)],
  })
  bb.insts.push(Instruction::{ opcode: Ret, defs: [], uses: [VFReg(3)] })
  func.body.push(bb)
  let result = vm.eval_function(func, [
    VMValue::Double(3.14),
    VMValue::Double(2.86),
  ])
  inspect(result, content="Double(6)") // The result should be Double(6.0)
}

///|
test "conditional branch" {
  let vm = VirtualMachine::new()
  let func = Function::new("test_branch")
  func.params.push(VReg(1))
  func.params.push(VReg(2))
  let entry_bb = BasicBlock::new("entry")
  entry_bb.insts.push(Instruction::{
    opcode: Beq,
    defs: [],
    uses: [VReg(1), VReg(2), Label("equal")],
  })
  entry_bb.insts.push(Instruction::{
    opcode: Jmp,
    defs: [],
    uses: [Label("not_equal")],
  })
  let equal_bb = BasicBlock::new("equal")
  equal_bb.insts.push(Instruction::{ opcode: Ret, defs: [], uses: [Imm(1L)] })
  let not_equal_bb = BasicBlock::new("not_equal")
  not_equal_bb.insts.push(Instruction::{
    opcode: Ret,
    defs: [],
    uses: [Imm(0L)],
  })
  func.body.push(entry_bb)
  func.body.push(equal_bb)
  func.body.push(not_equal_bb)

  // Test equal case
  let result1 = vm.eval_function(func, [VMValue::Int(5L), VMValue::Int(5L)])
  inspect(result1, content="Int(1)")

  // Test not equal case
  let result2 = vm.eval_function(func, [VMValue::Int(5L), VMValue::Int(3L)])
  inspect(result2, content="Int(0)")
}

///|
test "memory operations" {
  let vm = VirtualMachine::new()
  let func = Function::new("test_memory")
  let bb = BasicBlock::new("entry")
  // Store value 42 at memory address 100
  bb.insts.push(Instruction::{
    opcode: Storeq,
    defs: [],
    uses: [Imm(42L), Imm(100L)],
  })
  // Load value from memory address 100
  bb.insts.push(Instruction::{
    opcode: Loadq,
    defs: [VReg(1)],
    uses: [Imm(100L)],
  })
  bb.insts.push(Instruction::{ opcode: Ret, defs: [], uses: [VReg(1)] })
  func.body.push(bb)
  let result = vm.eval_function(func, [])
  inspect(result, content="Int(42)")
}

///|
test "comparison operations" {
  let vm = VirtualMachine::new()
  let func = Function::new("test_cmp")
  func.params.push(VReg(1))
  func.params.push(VReg(2))
  let bb = BasicBlock::new("entry")
  bb.insts.push(Instruction::{
    opcode: Lt,
    defs: [VReg(3)],
    uses: [VReg(1), VReg(2)],
  })
  bb.insts.push(Instruction::{
    opcode: Eq,
    defs: [VReg(4)],
    uses: [VReg(1), VReg(2)],
  })
  bb.insts.push(Instruction::{
    opcode: Addq,
    defs: [VReg(5)],
    uses: [VReg(3), VReg(4)],
  })
  bb.insts.push(Instruction::{ opcode: Ret, defs: [], uses: [VReg(5)] })
  func.body.push(bb)

  // Test 3 < 5 (true=1) and 3 == 5 (false=0), result should be 1
  let result = vm.eval_function(func, [VMValue::Int(3L), VMValue::Int(5L)])
  inspect(result, content="Int(1)")
}
