///|
pub struct IRBuilder {
  func : Function
  bb : BasicBlock
}

///|
fn check_bits(bits : Int, loc : SourceLoc) -> Unit raise MIRError {
  guard bits is (8 | 16 | 32 | 64) else {
    raise InValidBitWidthError("Invalid bit width: \{bits}, loc: \{loc}")
  }
}

///|
pub fn IRBuilder::new(func : Function, bb : BasicBlock) -> IRBuilder {
  IRBuilder::{ func, bb }
}

///|
#callsite(autofill(loc))
pub fn IRBuilder::build_loadi(
  self : Self,
  bits : Int,
  dst~ : IRegister,
  base~ : IRegister,
  offset~ : Int64,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::IRegister(dst)
  let src = Operand::Mem(base, offset)
  Instruction::new(ILoad(bits), [dst], [src], self.bb)
}

///|
#callsite(autofill(loc))
pub fn IRBuilder::build_loadf(
  self : Self,
  bits : Int,
  dst~ : FRegister,
  base~ : IRegister,
  offset~ : Int64,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::FRegister(dst)
  let src = Operand::Mem(base, offset)
  Instruction::new(FLoad(bits), [dst], [src], self.bb)
}

///|
#callsite(autofill(loc))
pub fn IRBuilder::build_storei(
  self : Self,
  bits : Int,
  src~ : IRegister,
  base~ : IRegister,
  offset~ : Int64,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let src = Operand::IRegister(src)
  let dst = Operand::Mem(base, offset)
  Instruction::new(IStore(bits), [], [dst, src], self.bb)
}

///|
#callsite(autofill(loc))
pub fn IRBuilder::build_storef(
  self : Self,
  bits : Int,
  src~ : FRegister,
  base~ : IRegister,
  offset~ : Int64,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let src = Operand::FRegister(src)
  let dst = Operand::Mem(base, offset)
  Instruction::new(FStore(bits), [], [dst, src], self.bb)
}

///|
#callsite(autofill(loc))
pub fn IRBuilder::build_ibinary(
  self : Self,
  binop : IBinaryOpCode,
  bits : Int,
  dst~ : IRegister,
  src1~ : IRegister,
  src2~ : IRegister,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::IRegister(dst)
  let src1 = Operand::IRegister(src1)
  let src2 = Operand::IRegister(src2)
  Instruction::new(IBinary(binop, bits), [dst], [src1, src2], self.bb)
}

///|
#callsite(autofill(loc))
pub fn IRBuilder::build_ibinary_imm(
  self : Self,
  binop : IBinaryOpCode,
  bits : Int,
  dst~ : IRegister,
  src1~ : IRegister,
  src2~ : Int64,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::IRegister(dst)
  let src1 = Operand::IRegister(src1)
  let src2 = Operand::Imm(src2)
  Instruction::new(IBinary(binop, bits), [dst], [src1, src2], self.bb)
}


#callsite(autofill(loc))
pub fn IRBuilder::build_fbinary(self: Self, binop: FBinaryOpCode, bits: Int, dst~: FRegister, src1~: FRegister, src2~: FRegister, loc~: SourceLoc) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::FRegister(dst)
  let src1 = Operand::FRegister(src1)
  let src2 = Operand::FRegister(src2)
  Instruction::new(FBinary(binop, bits), [dst], [src1, src2], self.bb)
}

#callsite(autofill(loc))
pub fn IRBuilder::build_fneg(self: Self, bits: Int, dst~: FRegister, src~: FRegister, loc~: SourceLoc) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::FRegister(dst)
  let src = Operand::FRegister(src)
  Instruction::new(FUnary(FNeg, bits), [dst], [src], self.bb)
}

#callsite(autofill(loc))
pub fn IRBuilder::build_icmp(self: Self, cmpop: ICmpOpCode, bits: Int, dst~: IRegister, src1~: IRegister, src2~: IRegister, loc~: SourceLoc) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::IRegister(dst)
  let src1 = Operand::IRegister(src1)
  let src2 = Operand::IRegister(src2)
  Instruction::new(ICmp(cmpop, bits), [dst], [src1, src2], self.bb)
}

#callsite(autofill(loc))
pub fn IRBuilder::build_icmp_imm(self: Self, cmpop: ICmpOpCode, bits: Int, dst~: IRegister, src1~: IRegister, src2~: Int64, loc~: SourceLoc) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::IRegister(dst)
  let src1 = Operand::IRegister(src1)
  let src2 = Operand::Imm(src2)
  Instruction::new(ICmp(cmpop, bits), [dst], [src1, src2], self.bb)
}

#callsite(autofill(loc))
pub fn IRBuilder::build_fcmp(self: Self, cmpop: FCmpOpCode, bits: Int, dst~: IRegister, src1~: FRegister, src2~: FRegister, loc~: SourceLoc) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::IRegister(dst)
  let src1 = Operand::FRegister(src1)
  let src2 = Operand::FRegister(src2)
  Instruction::new(FCmp(cmpop, bits), [dst], [src1, src2], self.bb)
}

///|
#callsite(autofill(loc))
pub fn IRBuilder::build_iunary(
  self : Self,
  unop : IUnaryOpCode,
  bits : Int,
  dst~ : IRegister,
  src~ : IRegister,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::IRegister(dst)
  let src = Operand::IRegister(src)
  Instruction::new(IUnary(unop, bits), [dst], [src], self.bb)
}

///|
#callsite(autofill(loc))
pub fn IRBuilder::build_imove(
  self : Self,
  bits : Int,
  dst~ : IRegister,
  src~ : IRegister,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::IRegister(dst)
  let src = Operand::IRegister(src)
  Instruction::new(IMove(bits), [dst], [src], self.bb)
}

///|
#callsite(autofill(loc))
pub fn IRBuilder::build_imove_imm(
  self : Self,
  bits : Int,
  dst~ : IRegister,
  src~ : Int64,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::IRegister(dst)
  let src = Operand::Imm(src)
  Instruction::new(IMove(bits), [dst], [src], self.bb)
}

///|
#callsite(autofill(loc))
pub fn IRBuilder::build_fmove(
  self : Self,
  bits : Int,
  dst~ : FRegister,
  src~ : FRegister,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::FRegister(dst)
  let src = Operand::FRegister(src)
  Instruction::new(FMove(bits), [dst], [src], self.bb)
}

///|
#callsite(autofill(loc))
pub fn IRBuilder::build_fmove_imm(
  self : Self,
  bits : Int,
  dst~ : FRegister,
  src~ : Double,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::FRegister(dst)
  let src = Operand::FImm(src)
  Instruction::new(FMove(bits), [dst], [src], self.bb)
}

#callsite(autofill(loc))
pub fn IRBuilder::build_fmove_from_ireg(
  self : Self,
  bits : Int,
  dst~ : FRegister,
  src~ : IRegister,
  loc~ : SourceLoc,
) -> Instruction raise MIRError {
  check_bits(bits, loc)
  let dst = Operand::FRegister(dst)
  let src = Operand::IRegister(src)
  Instruction::new(FMove(bits), [dst], [src], self.bb)
}

///|
pub fn IRBuilder::build_load_addr(
  self : Self,
  dst : IRegister,
  label : String,
) -> Instruction {
  let dst = Operand::IRegister(dst)
  let src = Operand::Label(label)
  Instruction::new(LoadAddr, [dst], [src], self.bb)
}

///|
pub fn IRBuilder::build_ret(self : Self) -> Instruction {
  Instruction::new(Ret, [], [], self.bb)
}

pub fn IRBuilder::build_branch(
  self: Self,
  opcode: BranchOpCode,
  lhs~: IRegister,
  rhs~: IRegister,
  true_label~: String, false_label~: String
) -> Instruction {
  let lhs = Operand::IRegister(lhs)
  let rhs = Operand::IRegister(rhs)
  let true_label = Operand::Label(true_label)
  let false_label = Operand::Label(false_label)
  Instruction::new(Branch(opcode), [], [lhs, rhs, true_label, false_label], self.bb)
}

pub fn IRBuilder::build_branch_imm(
  self: Self,
  opcode: BranchOpCode,
  lhs~: IRegister,
  rhs~: Int64,
  true_label~: String,
  false_label~: String
) -> Instruction {
  let lhs = Operand::IRegister(lhs)
  let rhs = Operand::Imm(rhs)
  let true_label = Operand::Label(true_label)
  let false_label = Operand::Label(false_label)
  Instruction::new(Branch(opcode), [], [lhs, rhs, true_label, false_label], self.bb)
}

pub fn IRBuilder::build_jmp(
  self: Self,
  target_label~: String
) -> Instruction {
  let target_label = Operand::Label(target_label)
  Instruction::new(Branch(Jmp), [], [target_label], self.bb)
}
