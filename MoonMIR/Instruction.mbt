///|
pub(all) struct Instruction {
  opcode : OpCode
  defs : Array[Operand]
  uses : Array[Operand]
  bb : BasicBlock
  func : Function
  livein : Set[Operand]
  liveout : Set[Operand]
}

///|
fn Instruction::new(
  opcode : OpCode,
  defs : Array[Operand],
  uses : Array[Operand],
  bb : BasicBlock,
) -> Instruction {
  Instruction::{
    opcode,
    defs,
    uses,
    bb,
    func: bb.parent,
    livein: Set::new(),
    liveout: Set::new(),
  }
}

///|
pub impl Show for Instruction with output(self, logger) {
  match self.defs {
    [] => ()
    [d] => logger.write_string("\{d} = ")
    _ as defs => {
      let defs_str = defs.map(d => "\{d}").join(", ")
      logger.write_string("(\{defs_str}) = ")
    }
  }
  logger.write_object(self.opcode)
  if self.uses.length() > 0 {
    let uses_str = self.uses.map(u => "\{u}").join(", ")
    logger.write_string(" \{uses_str}")
  }
}
