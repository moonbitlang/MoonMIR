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
pub fn BasicBlock::add_inst_before_terminator(
  self : Self,
  inst : Instruction,
) -> Unit {
  if self.insts.length() == 0 {
    self.insts.push(inst)
    return
  }
  if self.insts.last().unwrap().is_terminator() {
    self.insts.insert(self.insts.length() - 1, inst)
  } else {
    self.insts.push(inst)
  }
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
