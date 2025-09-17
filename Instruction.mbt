///|
pub(all) enum Operand {
  VReg(Int) // Virtual Register
  VFReg(Int) // Virtual Floating Point Register
  Reg(Int) // Physical Register
  FReg(Int) // Physical Floating Point Register
  Imm(Int64) // Immediate Value
  FImm(Double) // Floating Point Immediate Value
  Mem(Operand, Int) // Memory Addressing (Base, Offset)
  Label(String) // Label
  StackTop // Stack Top (for stack pointer)
} derive(Eq)

///|
pub impl Show for Operand with output(self, logger) {
  let s = match self {
    VReg(i) => "%v\{i}"
    VFReg(i) => "%vf\{i}"
    Reg(i) => "%r\{i}"
    FReg(i) => "%f\{i}"
    Imm(i) => "\{i}"
    FImm(f) => "\{f}"
    Mem(base, offset) => "(\{base} + \{offset})"
    Label(name) => "\{name}"
    StackTop => "sp"
  }
  logger.write_string(s)
}

///|
pub(all) struct Instruction {
  opcode : OpCode
  defs : Array[Operand]
  uses : Array[Operand]
}

///|
pub impl Show for Instruction with output(self, logger) {
  if self.defs.length() > 0 {
    let dstr = self.defs.map(op => op.to_string()).join(", ")
    logger.write_string(dstr)
    logger.write_string(" = ")
  }
  logger.write_string(self.opcode.to_string())
  logger.write_string(" ")
  if self.uses.length() > 0 {
    let ustr = self.uses.map(op => op.to_string()).join(", ")
    logger.write_string(ustr)
  }
}

///|
pub(all) struct BasicBlock {
  label : String
  mut insts : Array[Instruction]
  mut parent : Function?
  preds : Array[BasicBlock]
}

///|
pub fn BasicBlock::new(label : String) -> BasicBlock {
  BasicBlock::{ label, insts: Array::new(), parent: None, preds: Array::new() }
}

///|
pub impl Show for BasicBlock with output(self, logger) {
  logger.write_string(self.label)
  logger.write_string(":\n")
  for inst in self.insts {
    logger.write_string("  ")
    logger.write_string(inst.to_string())
    logger.write_string("\n")
  }
}

///|
pub(all) struct Function {
  name : String
  params : Array[Operand]
  body : Array[BasicBlock]
  mut stack_size : Int
}

///|
pub fn Function::new(name : String) -> Function {
  Function::{ name, params: Array::new(), body: Array::new(), stack_size: 0 }
}

///|
pub impl Show for Function with output(self, logger) {
  logger.write_string("func \{self.name}(")
  let pstr = self.params.map(p => p.to_string()).join(", ")
  logger.write_string(pstr)
  logger.write_string(") {\n")
  for bb in self.body {
    logger.write_string(bb.to_string())
  }
  logger.write_string("}\n")
}

///|
pub(all) struct Module {
  functions : Array[Function]
  // globals: Array[GlobalVariable] (not implemented yet)
}

///|
pub fn Module::new() -> Module {
  Module::{ functions: Array::new() }
}

///|
pub impl Show for Module with output(self, logger) {
  for func in self.functions {
    logger.write_string(func.to_string())
    logger.write_string("\n")
  }
}
