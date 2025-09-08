

pub(all) enum Operand {
  VReg(Int) // Virtual Register
  VFReg(Int) // Virtual Floating Point Register
  Reg(Int) // Physical Register
  FReg(Int) // Physical Floating Point Register
  Imm(Int) // Immediate Value
  Mem(Operand, Int) // Memory Addressing (Base, Offset)
  Label(String) // Label
  StackTop // Stack Top (for stack pointer)
}

pub impl Show for Operand with output(self, logger) {
  let s = match self {
    VReg(i) => "%v\{i}"
    VFReg(i) => "%vf\{i}"
    Reg(i) => "%r\{i}"
    FReg(i) => "%f\{i}"
    Imm(i) => "\{i}"
    Mem(base, offset) => "(\{base} + \{offset})"
    Label(name) => "\{name}"
    StackTop => "sp"
  }
  logger.write_string(s)
}


pub(all) struct Instruction {
  opcode: OpCode
  defs: Array[Operand]
  uses: Array[Operand]
}

pub impl Show for Instruction with output(self, logger) {
  logger.write_string(self.opcode.to_string())
  logger.write_string(" ")
  if self.uses.length() > 0 {
    let ustr = self.uses.map(op => op.to_string()).join(", ")
    logger.write_string(ustr)
  }
  if self.defs.length() > 0 {
    logger.write_string(" -> ")
    let dstr = self.defs.map(op => op.to_string()).join(", ")
    logger.write_string(dstr)
  }
}

pub(all) struct BasicBlock {
  label: String
  insts: Array[Instruction]
  mut parent: Function?
}

pub fn BasicBlock::new(label: String) -> BasicBlock {
  BasicBlock:: {
    label,
    insts: Array::new(),
    parent: None
  }
}

pub impl Show for BasicBlock with output(self, logger) {
  logger.write_string(self.label)
  logger.write_string(":\n")
  for inst in self.insts {
    logger.write_string("  ")
    logger.write_string(inst.to_string())
    logger.write_string("\n")
  }
}

pub(all) struct Function {
  name: String
  params: Array[Operand]
  body: Array[BasicBlock]
  mut stack_size: Int
}

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
