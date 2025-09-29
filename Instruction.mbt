///|
pub(all) struct Instruction {
  opcode : OpCode
  defs : Array[Operand]
  uses : Array[Operand]
  bb : BasicBlock?
  mut livein : Set[Operand]
  mut liveout : Set[Operand]
}

///|
pub(all) enum InstIterControl {
  DefUse
  UseDef
  All
}

///|
pub fn Instruction::op_iter(
  self : Self,
  ctrl : InstIterControl,
) -> Iter[Operand] {
  letrec def_use_f = yield_ => {
    for op in self.defs {
      guard yield_(op) is IterContinue else { return IterEnd }
    }
    for op in self.uses {
      guard yield_(op) is IterContinue else { return IterEnd }
    }
    IterContinue
  }

  letrec use_def_f = yield_ => {
    for op in self.uses {
      guard yield_(op) is IterContinue else { return IterEnd }
    }
    for op in self.defs {
      guard yield_(op) is IterContinue else { return IterEnd }
    }
    IterContinue
  }

  letrec all_f = yield_ => {
    for op in self.defs {
      guard yield_(op) is IterContinue else { return IterEnd }
    }
    for op in self.uses {
      guard yield_(op) is IterContinue else { return IterEnd }
    }
    for op in self.livein {
      guard yield_(op) is IterContinue else { return IterEnd }
    }
    for op in self.liveout {
      guard yield_(op) is IterContinue else { return IterEnd }
    }
    IterContinue
  }

  match ctrl {
    DefUse => Iter::new(def_use_f)
    UseDef => Iter::new(use_def_f)
    All => Iter::new(all_f)
  }
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
  // for debug, show livein and liveout
  // let livein_str = self.livein.iter().map(op => op.to_string()).join(", ")
  // logger.write_string(" [livein: {\{livein_str}}]")
  // let liveout_str = self.liveout.iter().map(op => op.to_string()).join(", ")
  // logger.write_string(" [liveout: {\{liveout_str}}]")
}

///|
fn Instruction::is_terminator(self : Self) -> Bool {
  self.opcode.is_terminator()
}

///|
pub fn Instruction::new(
  opcode : OpCode,
  defs : Array[Operand],
  uses : Array[Operand],
  bb? : BasicBlock? = None,
) -> Instruction {
  // Simplified version - just create the instruction without validation
  // All validation and normalization will be done in the Legalize phase
  Instruction::{
    opcode,
    defs,
    uses,
    bb,
    livein: Set::new(),
    liveout: Set::new(),
  }
}
