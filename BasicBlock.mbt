///|
pub(all) struct BasicBlock {
  mut llvm_bb : @IR.BasicBlock?
  label : String
  mut insts : Array[Instruction]
  parent : Function
  preds : Array[BasicBlock]
  succs : Array[BasicBlock]
  phi_nodes : Array[(@IR.PHINode, Operand)] // (phi node, operand)
  mut live_in : Set[Operand]
  mut live_out : Set[Operand]
}

///|
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
    phi_nodes: Array::new(),
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

///|
pub fn BasicBlock::push_inst_before_terminator(
  self : Self,
  inst : Instruction,
) -> Unit {
  if self.insts.is_empty() {
    self.insts.push(inst)
    return
  }
  let last_inst = self.insts.last().unwrap()
  if last_inst.opcode.is_terminator() {
    self.insts.insert(self.insts.length() - 1, inst)
  } else {
    self.insts.push(inst)
  }
}

// Return True is the live_out set was changed

///|
pub fn BasicBlock::update_live_out(
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
pub fn BasicBlock::update_live_in(self : Self, live_in : Set[Operand]) -> Bool {
  if self.live_in == live_in {
    return false
  }
  self.live_in = live_in
  true
}

///|
pub fn BasicBlock::compute_live_out_from_succs(self : Self) -> Set[Operand] {
  let live_out : Set[Operand] = Set::new()
  for succ in self.succs {
    succ.live_in.each(v => live_out.add(v))
  }
  live_out
}

///|
pub impl Show for BasicBlock with output(self, logger) {
  if !self.preds.is_empty() {
    let pred_labels = self.preds.map(b => b.label).join(", ")
    logger.write_string("; preds: \{pred_labels}\n")
  }
  let inst_strs : Array[(String, String)] = Array::new()
  let label_str = "\{self.label}:"
  let live_in_notes = if !self.live_in.is_empty() {
    let str = self.live_in.iter().map(op => "\{op}").join(", ")
    "; live in: \{str}"
  } else {
    ""
  }
  inst_strs.push((label_str, live_in_notes))
  for inst in self.insts {
    let inst_str = "  \{inst}"
    let live_str = if !inst.live_in.is_empty() {
      let str = inst.live_in.iter().map(op => "\{op}").join(", ")
      "# live in: \{str}"
    } else {
      ""
    }
    inst_strs.push((inst_str, live_str))
  }
  fn max(a : Int, b : Int) {
    if a > b {
      a
    } else {
      b
    }
  }

  let max_inst_len = inst_strs.map(p => p.0.length()).fold(init=0, max)
  for inst_str_pair in inst_strs {
    let (inst_str, live_str) = inst_str_pair
    if live_str is "" {
      logger.write_string("\{inst_str}\n")
      continue
    }
    let padding = " ".repeat(max_inst_len - inst_str.length() + 8)
    logger.write_string("\{inst_str}\{padding}\{live_str}\n")
  }
}
