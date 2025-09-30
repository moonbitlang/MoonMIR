///|
pub struct IRBuilder {
  func : Function
  bb : BasicBlock
}

///|
pub fn IRBuilder::new(func : Function, bb : BasicBlock) -> IRBuilder {
  IRBuilder::{ func, bb }
}

///|
pub fn IRBuilder::build_loadi(
  self : Self,
  bits : Int,
  dst~ : IRegister,
  base~ : IRegister,
  offset~ : Int64,
) -> Instruction {
  let dst = Operand::IRegister(dst)
  let src = Operand::Mem(base, offset)
  Instruction::new(ILoad(bits), [dst], [src], self.bb)
}

///|
pub fn IRBuilder::build_storei(
  self : Self,
  bits : Int,
  src~ : IRegister,
  base~ : IRegister,
  offset~ : Int64,
) -> Instruction {
  let src = Operand::IRegister(src)
  let dst = Operand::Mem(base, offset)
  Instruction::new(IStore(bits), [], [dst, src], self.bb)
}

///|
pub fn IRBuilder::build_ibinary(
  self : Self,
  binop : IBinaryOpCode,
  bits : Int,
  dst~ : IRegister,
  src1~ : IRegister,
  src2~ : IRegister,
) -> Instruction {
  let dst = Operand::IRegister(dst)
  let src1 = Operand::IRegister(src1)
  let src2 = Operand::IRegister(src2)
  Instruction::new(IBinary(binop, bits), [dst], [src1, src2], self.bb)
}

///|
pub fn IRBuilder::build_ibinary_imm(
  self : Self,
  binop : IBinaryOpCode,
  bits : Int,
  dst~ : IRegister,
  src1~ : IRegister,
  src2~ : Int64,
) -> Instruction {
  let dst = Operand::IRegister(dst)
  let src1 = Operand::IRegister(src1)
  let src2 = Operand::Imm(src2)
  Instruction::new(IBinary(binop, bits), [dst], [src1, src2], self.bb)
}

pub fn IRBuilder::build_iunary(
  self : Self,
  unop : IUnaryOpCode,
  bits : Int,
  dst~ : IRegister,
  src~ : IRegister,
) -> Instruction {
  let dst = Operand::IRegister(dst)
  let src = Operand::IRegister(src)
  Instruction::new(IUnary(unop, bits), [dst], [src], self.bb)
}

pub fn IRBuilder::build_imove(self: Self, bits: Int, dst~: IRegister, src~: IRegister) -> Instruction {
  let dst = Operand::IRegister(dst)
  let src = Operand::IRegister(src)
  Instruction::new(IMove(bits), [dst], [src], self.bb)
}

pub fn IRBuilder::build_imove_imm(self: Self, bits: Int, dst~: IRegister, src~: Int64) -> Instruction {
  let dst = Operand::IRegister(dst)
  let src = Operand::Imm(src)
  Instruction::new(IMove(bits), [dst], [src], self.bb)
}
