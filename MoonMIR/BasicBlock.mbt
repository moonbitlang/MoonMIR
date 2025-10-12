///|
pub(all) struct BasicBlock {
  mut llvm_bb : @IR.BasicBlock?
  label : String
  mut insts : Array[Instruction]
  parent : Function
  preds : Array[BasicBlock]
  succs: Array[BasicBlock]
  mut live_in : Set[Operand]
  mut live_out : Set[Operand]
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
    live_in: Set::new(),
    live_out: Set::new(),
  }
}

///|
pub fn BasicBlock::clear(self : Self) -> Unit {
  self.insts.clear()
  self.preds.clear()
  self.live_in.clear()
  self.live_out.clear()
}

///|
pub fn BasicBlock::push(self : Self, inst : Instruction) -> Unit {
  self.insts.push(inst)
}

// Return True is the live_out set was changed
pub fn BasicBlock::update_live_out(self: Self, live_out: Set[Operand]) -> Bool {
  if self.live_out == live_out {
    return false
  }
  self.live_out = live_out
  true
}

pub fn BasicBlock::update_live_in(self: Self, live_in: Set[Operand]) -> Bool {
  if self.live_in == live_in {
    return false
  }
  self.live_in = live_in
  true
}

pub fn BasicBlock::compute_live_out_from_succs(self: Self) -> Set[Operand] {
  let live_out: Set[Operand] = Set::new()
  for succ in self.succs {
    succ.live_in.each(v => live_out.add(v))
  }
  live_out
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
    if !inst.live_in.is_empty() {
      let str = inst.live_in.iter().map(op => "\{op}").join(", ")
      logger.write_string("  # live: \{str}\n")
    }
    logger.write_string("  ")
    logger.write_string(inst.to_string())
    logger.write_string("\n")
  }
}
