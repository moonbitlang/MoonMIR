pub(all) struct Mem {
  base: Reg
  offset: Int
} derive(Eq, Compare, Hash)

pub(all) struct Label (String) derive(Eq, Compare, Hash)

pub(all) enum Reg {
  Zero
  Ra
  Sp
  Gp
  Tp
  T0
  T1
  T2
  Fp
  S1
  A0
  A1
  A2
  A3
  A4
  A5
  A6
  A7
  S2
  S3
  S4
  S5
  S6
  S7
  S8
  S9
  S10
  S11
  T3
  T4
  T5
  T6
} derive(Eq, Compare, Hash)

///| RISC-V floating point register
pub(all) enum FReg {
  Ft0
  Ft1
  Ft2
  Ft3
  Ft4
  Ft5
  Ft6
  Ft7
  Fs0
  Fs1
  Fa0
  Fa1
  Fa2
  Fa3
  Fa4
  Fa5
  Fa6
  Fa7
  Fs2
  Fs3
  Fs4
  Fs5
  Fs6
  Fs7
  Fs8
  Fs9
  Fs10
  Fs11
  Ft8
  Ft9
  Ft10
  Ft11
} derive(Eq, Compare, Hash)

///|
pub(all) enum RvAsm {
  // reg-reg arith
  Add(Reg, Reg, Reg)
  Sub(Reg, Reg, Reg)
  Xor(Reg, Reg, Reg)
  Or(Reg, Reg, Reg)
  And(Reg, Reg, Reg)
  Sll(Reg, Reg, Reg)
  Srl(Reg, Reg, Reg)
  Sra(Reg, Reg, Reg)
  Slt(Reg, Reg, Reg)
  Sltu(Reg, Reg, Reg)
  // reg-imm arith
  Addi(Reg, Reg, Int)
  Xori(Reg, Reg, Int)
  Ori(Reg, Reg, Int)
  Andi(Reg, Reg, Int)
  Slli(Reg, Reg, Int)
  Srli(Reg, Reg, Int)
  Srai(Reg, Reg, Int)
  Slti(Reg, Reg, Int)
  Sltiu(Reg, Reg, Int)
  // mem
  // memory access
  Lb(Reg, Mem)
  Lh(Reg, Mem)
  Lw(Reg, Mem)
  Ld(Reg, Mem)
  Lbu(Reg, Mem)
  Lhu(Reg, Mem)
  Lwu(Reg, Mem)
  Sb(Reg, Mem)
  Sh(Reg, Mem)
  Sw(Reg, Mem)
  Sd(Reg, Mem)
  // control 
  Beq(Reg, Reg, Label)
  Bne(Reg, Reg, Label)
  Blt(Reg, Reg, Label)
  Bge(Reg, Reg, Label)
  Ble(Reg, Reg, Label)
  Bgt(Reg, Reg, Label)
  Bltu(Reg, Reg, Label)
  Bgeu(Reg, Reg, Label)
  // system
  Ecall
  // rv32/64m
  Mul(Reg, Reg, Reg)
  Mulw(Reg, Reg, Reg)
  Mulh(Reg, Reg, Reg)
  Mulhsu(Reg, Reg, Reg)
  Mulhu(Reg, Reg, Reg)
  Div(Reg, Reg, Reg)
  Divw(Reg, Reg, Reg)
  Divu(Reg, Reg, Reg)
  Rem(Reg, Reg, Reg)
  Remw(Reg, Reg, Reg)
  Remu(Reg, Reg, Reg)
  // rvf
  FaddD(FReg, FReg, FReg)
  FsubD(FReg, FReg, FReg)
  FmulD(FReg, FReg, FReg)
  FdivD(FReg, FReg, FReg)
  Fld(FReg, Mem)
  Fsd(FReg, Mem)
  FeqD(Reg, FReg, FReg)
  FleD(Reg, FReg, FReg)
  FmvDX(FReg, Reg)
  // pseudo instructions
  Nop
  La(Reg, Label)
  Li(Reg, String)
  Neg(Reg, Reg)
  FnegD(FReg, FReg)
  Mv(Reg, Reg)
  FmvD(FReg, FReg)
  J(Label)
  Jalr(Reg)
  Jr(Reg)
  Call(Label)
  Tail(Label)
  Ret
  // Comments
  Label(String)
  Comment(String)
}
