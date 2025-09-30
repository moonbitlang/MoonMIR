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
pub fn BasicBlock::new(
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
pub fn BasicBlock::push_inst(
  self : Self,
  opcode : OpCode,
  defs : Array[Operand],
  uses : Array[Operand],
) -> Instruction {
  let inst = Instruction::new(opcode, defs, uses, self)
  self.insts.push(inst)
  inst
}

// pub fn BasicBlock::insert_inst_before_terminator(self: Self, opcode: OpCode, defs: Array[Operand>, uses: Array[Operand>) -> Instruction {
