///|
pub(all) enum OpCode {
  Addb
  Addw
  Addl
  Addq
  Add(Int)
  Subb
  Subw
  Subl
  Subq
  Sub(Int)
  Mulb
  Mulw
  Mull
  Mulq
  Mul(Int)
  Divb
  Divw
  Divl
  Divq
  Div(Int)
  Remb
  Remw
  Reml
  Remq
  Rem(Int)
  FAddS
  FAddD
  FSubS
  FSubD
  FMulS
  FMulD
  FDivS
  FDivD
  FRemS
  FRemD
  FNegS
  FNegD
  Loadb
  Loadw
  Loadl
  Loadq
  Load(Int)
  FLoadS
  FLoadD
  Storeb
  Storew
  Storel
  Storeq
  Store(Int)
  FStoreS
  FStoreD
  Movb
  Movw
  Movl
  Movq
  Mov(Int)
  FMovS
  FMovD
  Beq
  Bne
  Bgt
  Bge
  Blt
  Ble
  Bequ
  Bneu
  Bgtu
  Bgeu
  Bltu
  Bleu
  Jmp
  Eq
  Ne
  Gt
  Ge
  Lt
  Le
  Equ
  Neu
  Gtu
  Geu
  Ltu
  Leu
  FeqS
  FneS
  FgtS
  FgeS
  FltS
  FleS
  FeqD
  FneD
  FgtD
  FgeD
  FltD
  FleD
  And
  Or
  Xor
  Shl
  LShr
  AShr
  Trunc // i64 -> i32
  ZExt // i32 -> i64 (Zero Extend)
  SExt // i32 -> i64 (Sign Extend)
  FPTrunc // f64 -> f32
  FPExt // f32 -> f64
  FPToSI(Int, Int)
  FPToUI(Int, Int)
  SIToFP(Int, Int)
  UIToFP(Int, Int)
  BitCast
  Call
  PHI
  Select
  Ret
  Nop
  Intrinsic(String)
} derive(Hash, Show, Eq)

///|
pub(all) enum Operand {
  VReg(Int) // Virtual Register
  VFReg(Int) // Virtual Floating Point Register
  Reg(Int) // Physical Register
  FReg(Int) // Physical Floating Point Register
  Imm(Int64) // Immediate Value
  FImm(Double) // Floating Point Immediate Value
  AReg(Int) // Argument Register // Appeared in Post Register Allocation
  TReg(Int) // Temporary Register // Appeared in Post Register Allocation
  SReg(Int) // Saved Register // Appeared in Post Register Allocation
  FAReg(Int) // Argument Floating Point Register // Appeared in Post Register Allocation
  FTReg(Int) // Temporary Floating Point Register // Appeared in Post Register Allocation
  FSReg(Int) // Saved Floating Point Register // Appeared in Post Register Allocation
  Mem(Operand, Int64) // Memory Addressing (Base, Offset)
  Label(String) // Label
  StackPtr // Stack Top (for stack pointer)
  FramePtr // Frame Pointer
  FramePtrPrim // fp', fake frame pointer used in prologue/epilogue
  ReturnAddr // Return Address (for jalr instruction)
} derive(Hash, Eq)

///|
pub impl Show for Operand with output(self, logger) {
  let s = match self {
    VReg(i) => "%v\{i}"
    VFReg(i) => "%vf\{i}"
    Reg(i) => "%r\{i}"
    FReg(i) => "%f\{i}"
    AReg(i) => "%a\{i}"
    TReg(i) => "%t\{i}"
    SReg(i) => "%s\{i}"
    FAReg(i) => "%fa\{i}"
    FTReg(i) => "%ft\{i}"
    FSReg(i) => "%fs\{i}"
    Imm(i) => "\{i}"
    FImm(f) => "\{f}"
    Mem(base, offset) =>
      if offset < 0 {
        "(\{base} - \{-offset})"
      } else {
        "(\{base} + \{offset})"
      }
    Label(name) => "\{name}"
    StackPtr => "sp"
    FramePtr => "fp"
    FramePtrPrim => "fp'"
    ReturnAddr => "ra"
  }
  logger.write_string(s)
}

///|
fn OpCode::is_terminator(self : Self) -> Bool {
  self
  is (Ret
  | Jmp
  | Beq
  | Bne
  | Bgt
  | Bge
  | Blt
  | Ble
  | Bequ
  | Bneu
  | Bgtu
  | Bgeu
  | Bltu
  | Bleu)
}
