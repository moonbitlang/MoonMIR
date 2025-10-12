///|
pub(all) enum IBinaryOpCode {
  Add
  Sub
  Mul
  Div
  Rem
  And
  Or
  Xor
  Shl
  LShr
  AShr
}

///|
pub fn IBinaryOpCode::is_commutative(self : Self) -> Bool {
  match self {
    Add | Mul | And | Or | Xor => true
    Sub | Div | Rem => false
    Shl | LShr | AShr => false
  }
}

///|
pub(all) enum IUnaryOpCode {
  Not
}

///|
pub(all) enum ICmpOpCode {
  Eq
  Ne
  Gt
  Ge
  Lt
  Le
  Gtu
  Geu
  Ltu
  Leu
}

///|
pub(all) enum BranchOpCode {
  Beq
  Bne
  Bgt
  Bge
  Blt
  Ble
  Bgtu
  Bgeu
  Bltu
  Bleu
  Jmp
}

///|
pub(all) enum FBinaryOpCode {
  FAdd
  FSub
  FMul
  FDiv
  FRem
}

pub fn FBinaryOpCode::is_commutative(self : Self) -> Bool {
  match self {
    FAdd | FMul => true
    FSub | FDiv | FRem => false
  }
}

///|
pub(all) enum FUnaryOpCode {
  FNeg
}

///|
pub(all) enum FCmpOpCode {
  Feq
  Fne
  Fgt
  Fge
  Flt
  Fle
}

///|
pub(all) enum OpCode {
  IBinary(IBinaryOpCode, Int) // Int is the bit width (8, 16, 32, 64)
  IUnary(IUnaryOpCode, Int) // Int is the bit width (8, 16, 32, 64)
  ICmp(ICmpOpCode, Int) // Int is the bit width (8, 16, 32, 64)
  ILoad(Int) // Int is the bit width (8, 16, 32, 64)
  IStore(Int) // Int is the bit width (8, 16, 32, 64)
  IMove(Int) // Int is the bit width (8, 16, 32, 64)
  Branch(BranchOpCode)
  FBinary(FBinaryOpCode, Int) // Int is the bit width (32, 64)
  FUnary(FUnaryOpCode, Int) // Int is the bit width (32, 64)
  FCmp(FCmpOpCode, Int) // Int is the bit width (32, 64)
  FLoad(Int) // Int is the bit width (32, 64)
  FStore(Int) // Int is the bit width (32, 64)
  FMove(Int) // Int is the bit width (32, 64)
  FMoveI(Int) // Int is the float bit width (32, 64), move from int to float register
  IMoveF(Int) // Int is the float bit width (32, 64), move from float to int register
  LoadAddr // Load address of a variable
  Trunc(from~ : Int, to~ : Int)
  ZExt(from~ : Int, to~ : Int)
  SExt(from~ : Int, to~ : Int)
  FPTrunc(from~ : Int, to~ : Int)
  FPExt(from~ : Int, to~ : Int)
  FPToSI(from~ : Int, to~ : Int)
  FPToUI(from~ : Int, to~ : Int)
  SIToFP(from~ : Int, to~ : Int)
  UIToFP(from~ : Int, to~ : Int)
  Call
  Phi
  Select
  Ret
  Nop
  Intrinsic(String)
}

pub fn OpCode::is_terminator(self : Self) -> Bool {
  match self {
    Branch(_) | Ret => true
    _ => false
  }
}

///|
pub impl Show for OpCode with output(self, logger) {
  let s = match self {
    IBinary(op, bits) =>
      match op {
        Add => "add.i\{bits}"
        Sub => "sub.i\{bits}"
        Mul => "mul.i\{bits}"
        Div => "div.i\{bits}"
        Rem => "rem.i\{bits}"
        And => "and.i\{bits}"
        Or => "or.i\{bits}"
        Xor => "xor.i\{bits}"
        Shl => "shl.i\{bits}"
        LShr => "lshr.i\{bits}"
        AShr => "ashr.i\{bits}"
      }
    IUnary(op, bits) =>
      match op {
        Not => "not.i\{bits}"
      }
    ICmp(op, bits) =>
      match op {
        Eq => "eq.i\{bits}"
        Ne => "ne.i\{bits}"
        Gt => "gt.i\{bits}"
        Ge => "ge.i\{bits}"
        Lt => "lt.i\{bits}"
        Le => "le.i\{bits}"
        Gtu => "gtu.i\{bits}"
        Geu => "geu.i\{bits}"
        Ltu => "ltu.i\{bits}"
        Leu => "leu.i\{bits}"
      }
    ILoad(bits) => "load.i\{bits}"
    IStore(bits) => "store.i\{bits}"
    IMove(bits) => "move.i\{bits}"
    Branch(op) =>
      match op {
        Beq => "beq"
        Bne => "bne"
        Bgt => "bgt"
        Bge => "bge"
        Blt => "blt"
        Ble => "ble"
        Bgtu => "bgtu"
        Bgeu => "bgeu"
        Bltu => "bltu"
        Bleu => "bleu"
        Jmp => "jmp"
      }
    FBinary(op, bits) =>
      match op {
        FAdd => "fadd.f\{bits}"
        FSub => "fsub.f\{bits}"
        FMul => "fmul.f\{bits}"
        FDiv => "fdiv.f\{bits}"
        FRem => "frem.f\{bits}"
      }
    FUnary(op, bits) =>
      match op {
        FNeg => "fneg.f\{bits}"
      }
    FCmp(op, bits) =>
      match op {
        Feq => "feq.f\{bits}"
        Fne => "fne.f\{bits}"
        Fgt => "fgt.f\{bits}"
        Fge => "fge.f\{bits}"
        Flt => "flt.f\{bits}"
        Fle => "fle.f\{bits}"
      }
    FLoad(bits) => "load.f\{bits}"
    FStore(bits) => "store.f\{bits}"
    FMove(bits) => "move.f\{bits}"
    FMoveI(bits) => "fmovei.f\{bits}"
    IMoveF(bits) => "imovef.f\{bits}"
    LoadAddr => "loadaddr"
    Trunc(from~, to~) => "trunc.i\{from}_to_i\{to}"
    ZExt(from~, to~) => "zext.i\{from}_to_i\{to}"
    SExt(from~, to~) => "sext.i\{from}_to_i\{to}"
    FPTrunc(from~, to~) => "fptrunc.f\{from}_to_f\{to}"
    FPExt(from~, to~) => "fpext.f\{from}_to_f\{to}"
    FPToSI(from~, to~) => "fptosi.f\{from}_to_i\{to}"
    FPToUI(from~, to~) => "fptoui.f\{from}_to_i\{to}"
    SIToFP(from~, to~) => "sitofp.i\{from}_to_f\{to}"
    UIToFP(from~, to~) => "uitofp.i\{from}_to_f\{to}"
    Call => "call"
    Phi => "phi"
    Select => "select"
    Ret => "ret"
    Nop => "nop"
    Intrinsic(name) => "intrinsic.\{name}"
  }
  logger.write_string(s)
}
