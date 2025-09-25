///|
pub(all) struct BasicBlock {
  llvm_bb : @IR.BasicBlock
  label : String
  mut insts : Array[Instruction]
  parent : Function
  preds : Array[BasicBlock]
  livein : Set[Operand]
  liveout : Set[Operand]
}

///|
fn BasicBlock::new(
  func : Function,
  llvm_bb : @IR.BasicBlock,
  label : String,
) -> BasicBlock {
  BasicBlock::{
    llvm_bb,
    label,
    insts: Array::new(),
    parent: func,
    preds: Array::new(),
    livein: Set::new(),
    liveout: Set::new(),
  }
}

///|
fn BasicBlock::successors_label(self : Self) -> Array[String] {
  guard self.insts.last() is Some(last_inst) else { return Array::new() }
  let succ_labels = Array::new()
  if last_inst
    is {
      opcode: Beq
      | Bne
      | Bgt
      | Blt
      | Bge
      | Ble
      | Bequ
      | Bneu
      | Bgtu
      | Bgeu
      | Bltu
      | Bleu
      | Jmp,
      uses,
      ..,
    } {
    uses.each(u => if u is Label(l) { succ_labels.push(l) })
  }
  succ_labels
}

/////|
//pub fn BasicBlock::new(llvm_bb: @IR.BasicBlock, label : String) -> BasicBlock {
//  BasicBlock::{ llvm_bb, label, insts: Array::new(), parent: None, preds: Array::new() }
//}

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
pub fn BasicBlock::run_ir_translation(
  self : Self,
) -> Unit raise IRTranslateError {
  for inst in self.llvm_bb.instIter() {
    let minsts = Instruction::from_llvm_inst(inst, self) catch {
      e => {
        println("Error converting instruction in BB \{self.label}:")
        println("  Instruction: \{inst}")
        raise e
      }
    }
    minsts.each(i => self.insts.push(i))
  }
}

///|
pub impl Show for BasicBlock with output(self, logger) {
  logger.write_string(self.label)
  logger.write_string(":                 ")
  let pred_labels = self.preds.map(b => b.label).join(", ")
  logger.write_string("  ; preds: \{pred_labels}\n")
  for inst in self.insts {
    logger.write_string("  ")
    logger.write_string(inst.to_string())
    logger.write_string("\n")
  }
}
