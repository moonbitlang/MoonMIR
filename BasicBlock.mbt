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


