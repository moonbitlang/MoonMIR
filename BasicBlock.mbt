///|
pub(all) struct BasicBlock {
  llvm_bb : @IR.BasicBlock
  label : String
  mut insts : Array[Instruction]
  parent : Function
  preds : Array[BasicBlock]
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
  }
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
  logger.write_string(":\n")
  for inst in self.insts {
    logger.write_string("  ")
    logger.write_string(inst.to_string())
    logger.write_string("\n")
  }
}
