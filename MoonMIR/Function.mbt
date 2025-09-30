///|
///
///  ---------- fp
///     reg_stack
///  { callee-saved registers }
///  { spilled registers }
///  { temporary space for registers }
///  ---------- fp'
///     var_stack
///  { local variables }
///  { function parameters passed on stack }
///  ---------- sp
pub(all) struct Function {
  mod : Module

  // Function Attributes
  name : String
  params : Array[Operand]
  body : Array[BasicBlock]
  mut var_stack_size : Int64
  mut reg_stack_size : Int64
  //terminal_basic_blocks : Array[BasicBlock] // BasicBlocks that end with ret instruction

  // LLVM
  llvm_func : @IR.Function
  is_external : Bool

  // Value Map
  value_map : Map[&@IR.Value, Operand]
  bbmap : Map[String, BasicBlock] // Map from label to BasicBlock
  mut vreg_cnt : Int
  mut vfreg_cnt : Int

  // phase tracking
  mut ir_translated : Bool
}

///|
pub fn Function::new_virtual_reg(self : Self) -> IRegister {
  let vreg = IRegister::VReg(self.vreg_cnt)
  self.vreg_cnt += 1
  vreg
}

///|
pub fn Function::new_virtual_freg(self : Self) -> FRegister {
  let vfreg = FRegister::VFReg(self.vfreg_cnt)
  self.vfreg_cnt += 1
  vfreg
}
