///|
pub(all) struct BasicBlock {
  mut llvm_bb : @IR.BasicBlock?
  label : String
  mut insts : Array[Instruction]
  parent : Function
  preds : Array[BasicBlock]
  succs: Array[BasicBlock]
  livein : Set[Operand]
  liveout : Set[Operand]
}

pub impl Eq for BasicBlock with equal(self, other) {
  self.label == other.label
}

///|
pub fn BasicBlock::new(func : Function, label : String) -> BasicBlock {
  BasicBlock::{
    llvm_bb: None,
    label,
    insts: Array::new(),
    parent: func,
    preds: Array::new(),
    succs: Array::new(),
    livein: Set::new(),
    liveout: Set::new(),
  }
}

///|
pub fn BasicBlock::clear(self : Self) -> Unit {
  self.insts.clear()
  self.preds.clear()
  self.livein.clear()
  self.liveout.clear()
}

///|
pub fn BasicBlock::push(self : Self, inst : Instruction) -> Unit {
  self.insts.push(inst)
}

///|
pub impl Show for BasicBlock with output(self, logger) {
  logger.write_string(self.label)
  logger.write_string(":")
  if !self.preds.is_empty() {
    let pred_labels = self.preds.map(b => b.label).join(", ")
    logger.write_string("                       ")
    logger.write_string("; preds: \{pred_labels}")
  }
  logger.write_string("\n")
  for inst in self.insts {
    logger.write_string("  ")
    logger.write_string(inst.to_string())
    logger.write_string("\n")
  }
}
