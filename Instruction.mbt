///|
pub(all) struct Instruction {
  opcode : OpCode
  defs : Array[Operand]
  uses : Array[Operand]
  bb : BasicBlock
  func : Function
  mut live_in : Set[Operand]
  mut live_out : Set[Operand]
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
    live_in: Set::new(),
    live_out: Set::new(),
  }
}

///|
///
/// Returns true if live_in changed.
pub fn Instruction::update_live_out(
  self : Self,
  live_out : Set[Operand],
) -> Bool {
  if self.live_out == live_out {
    return false
  }
  self.live_out = live_out
  true
}

///|
///
/// Returns true if live_out changed.
pub fn Instruction::update_live_in(self : Self, live_in : Set[Operand]) -> Bool {
  if self.live_in == live_in {
    return false
  }
  self.live_in = live_in
  true
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
