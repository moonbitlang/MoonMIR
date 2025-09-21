//|

///|
pub suberror LegalizeError String derive(Show)

///|
pub fn Module::legalize(self : Self) -> Unit raise LegalizeError {
  if self.legalized {
    raise LegalizeError("Module is already legalized")
  }
  self.functions.each(f => f.legalize())
}

///|
pub fn Function::legalize(func : Function) -> Unit raise LegalizeError {
  if func.legalized {
    raise LegalizeError("Function is already legalized")
  }
  for bb in func.body {
    bb.legalize()
  }
}

///|
pub fn BasicBlock::legalize(self : BasicBlock) -> Unit raise LegalizeError {
  let new_insts : Array[Instruction] = Array::new()
  for inst in self.insts {
    inst.legalize().each(new_inst => new_insts.push(new_inst))
  }
  self.insts = new_insts
}

///|
pub fn Instruction::legalize(
  self : Instruction,
) -> Array[Instruction] raise LegalizeError {
  if false {
    raise LegalizeError("Instruction legalization not implemented yet")
  }
  [self] // Placeholder: return the instruction unchanged
}
