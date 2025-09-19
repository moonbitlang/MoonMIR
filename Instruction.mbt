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
fn Instruction::is_terminator(self : Self) -> Bool {
  self.opcode.is_terminator()
}

fn Instruction::new(opcode: OpCode, defs: Array[Operand], uses: Array[Operand]) -> Instruction {
  match (opcode, defs, uses) {
    (Addb, [Reg(_)], [Reg(_), Reg(_)]) => Instruction::{opcode, defs, uses}
    (Addb, [Reg(_)], [Reg(_), Imm(_)]) => Instruction::{opcode, defs, uses}
    (Addb, [Reg(_)], [Imm(_) as i, Reg(_) as j]) => Instruction::{opcode, defs, uses: [j, i]}
    (Addb, [VReg(_)], [VReg(_), VReg(_)]) => Instruction::{opcode, defs, uses}
    (Addb, [VReg(_)], [VReg(_), Imm(_)]) => Instruction::{opcode, defs, uses}
    (Addb, [VReg(_)], [Imm(_) as i, VReg(_) as j]) => Instruction::{opcode, defs, uses: [j, i]}
    (Addw, [Reg(_)], [Reg(_), Reg(_)]) => Instruction::{opcode, defs, uses}
    (Addw, [Reg(_)], [Reg(_), Imm(_)]) => Instruction::{opcode, defs, uses}
    (Addw, [Reg(_)], [Imm(_) as i, Reg(_) as j]) => Instruction::{opcode, defs, uses: [j, i]}
    (Addw, [VReg(_)], [VReg(_), VReg(_)]) => Instruction::{opcode, defs, uses}
    (Addw, [VReg(_)], [VReg(_), Imm(_)]) => Instruction::{opcode, defs, uses}
    (Addw, [VReg(_)], [Imm(_) as i, VReg(_) as j]) => Instruction::{opcode, defs, uses: [j, i]}
    (Addl, [Reg(_)], [Reg(_), Reg(_)]) => Instruction::{opcode, defs, uses}
    (Addl, [Reg(_)], [Reg(_), Imm(_)]) => Instruction::{opcode, defs, uses}
    (Addl, [Reg(_)], [Imm(_) as i, Reg(_) as j]) => Instruction::{opcode, defs, uses: [j, i]}
    (Addl, [VReg(_)], [VReg(_), VReg(_)]) => Instruction::{opcode, defs, uses}
    (Addl, [VReg(_)], [VReg(_), Imm(_)]) => Instruction::{opcode, defs, uses}
    (Addl, [VReg(_)], [Imm(_) as i, VReg(_) as j]) => Instruction::{opcode, defs, uses: [j, i]}
    (Addq, [Reg(_)], [Reg(_), Reg(_)]) => Instruction::{opcode, defs, uses}
    (Addq, [Reg(_)], [Reg(_), Imm(_)]) => Instruction::{opcode, defs, uses}
    (Addq, [Reg(_)], [Imm(_) as i, Reg(_) as j]) => Instruction::{opcode, defs, uses: [j, i]}
    (Addq, [VReg(_)], [VReg(_), VReg(_)]) => Instruction::{opcode, defs, uses}
    (Addq, [VReg(_)], [VReg(_), Imm(_)]) => Instruction::{opcode, defs, uses}
    (Addq, [VReg(_)], [Imm(_) as i, VReg(_) as j]) => Instruction::{opcode, defs, uses: [j, i]}
    _ => {
      println("Invalid instruction format:")
      println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
      panic()
    }
  }
}
