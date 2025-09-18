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

