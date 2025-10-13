///|
pub suberror MIRToRiscvError String derive(Show)

///|
#callsite(autofill(loc))
pub fn Reg::from_mir_reg(
  v : @MoonMIR.IRegister,
  loc~ : SourceLoc,
) -> Reg raise MIRToRiscvError {
  match v {
    AReg(0) => A0
    AReg(1) => A1
    AReg(2) => A2
    AReg(3) => A3
    AReg(4) => A4
    AReg(5) => A5
    AReg(6) => A6
    AReg(7) => A7
    TReg(0) => T0
    TReg(1) => T1
    TReg(2) => T2
    TReg(3) => T3
    TReg(4) => T4
    TReg(5) => T5
    TReg(6) => T6
    SReg(0) => S1
    SReg(1) => S2
    SReg(2) => S3
    SReg(3) => S4
    SReg(4) => S5
    SReg(5) => S6
    SReg(6) => S7
    SReg(7) => S8
    SReg(8) => S9
    SReg(9) => S10
    SReg(10) => S11
    StackPtr => Sp
    FramePtr => Fp // S0
    ReturnAddr => Ra
    _ =>
      raise MIRToRiscvError(
        "Error: Unsupported MoonMIR register: \{v}, loc: \{loc}",
      )
  }
}

///|
#callsite(autofill(loc))
pub fn FReg::from_mir_freg(
  v : @MoonMIR.FRegister,
  loc~ : SourceLoc,
) -> FReg raise MIRToRiscvError {
  match v {
    FAReg(0) => Fa0
    FAReg(1) => Fa1
    FAReg(2) => Fa2
    FAReg(3) => Fa3
    FAReg(4) => Fa4
    FAReg(5) => Fa5
    FAReg(6) => Fa6
    FAReg(7) => Fa7
    FTReg(0) => Ft0
    FTReg(1) => Ft1
    FTReg(2) => Ft2
    FTReg(3) => Ft3
    FTReg(4) => Ft4
    FTReg(5) => Ft5
    FTReg(6) => Ft6
    FTReg(7) => Ft7
    FSReg(0) => Fs0
    FSReg(1) => Fs1
    FSReg(2) => Fs2
    FSReg(3) => Fs3
    FSReg(4) => Fs4
    FSReg(5) => Fs5
    FSReg(6) => Fs6
    FSReg(7) => Fs7
    FSReg(8) => Fs8
    FSReg(9) => Fs9
    FSReg(10) => Fs10
    FSReg(11) => Fs11
    _ =>
      raise MIRToRiscvError(
        "Error: Unsupported MoonMIR floating-point register: \{v}, loc: \{loc}",
      )
  }
}

///|
pub fn mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  match inst.opcode {
    IBinary(Add, 32) => i32_add_mir_to_riscv(inst)
    IBinary(Add, 64) => i64_add_mir_to_riscv(inst)
    IBinary(Sub, 32) => i32_sub_mir_to_riscv(inst)
    IBinary(Sub, 64) => i64_sub_mir_to_riscv(inst)
    IBinary(Mul, 32) => i32_mul_mir_to_riscv(inst)
    IBinary(Mul, 64) => i64_mul_mir_to_riscv(inst)
    IBinary(Div, 32) => i32_div_mir_to_riscv(inst)
    IBinary(Div, 64) => i64_div_mir_to_riscv(inst)
    IBinary(Rem, 32) => i32_rem_mir_to_riscv(inst)
    IBinary(Rem, 64) => i64_rem_mir_to_riscv(inst)
    IBinary(And, _) => and_mir_to_riscv(inst)
    IBinary(Or, _) => or_mir_to_riscv(inst)
    IBinary(Xor, _) => xor_mir_to_riscv(inst)
    IBinary(Shl, 32) => i32_shl_mir_to_riscv(inst)
    IBinary(Shl, 64) => i64_shl_mir_to_riscv(inst)
    IBinary(LShr, 32) => i32_lshr_mir_to_riscv(inst)
    IBinary(LShr, 64) => i64_lshr_mir_to_riscv(inst)
    IUnary(Not, 32) => i32_not_mir_to_riscv(inst)
    IUnary(Not, 64) => i64_not_mir_to_riscv(inst)
    ICmp(Eq, _) => cmp_eq_mir_to_riscv(inst)
    ICmp(Ne, _) => cmp_ne_mir_to_riscv(inst)
    ICmp(Lt, _) => cmp_lt_mir_to_riscv(inst)
    ICmp(Gt, _) => cmp_gt_mir_to_riscv(inst)
    ICmp(Ltu, _) => cmp_ltu_mir_to_riscv(inst)
    ICmp(Gtu, _) => cmp_gtu_mir_to_riscv(inst)
    ILoad(32) => i32_load_mir_to_riscv(inst)
    ILoad(64) => i64_load_mir_to_riscv(inst)
    IStore(32) => i32_store_mir_to_riscv(inst)
    IStore(64) => i64_store_mir_to_riscv(inst)
    IMove(_) => move_mir_to_riscv(inst)
    Branch(Beq) => branch_eq_mir_to_riscv(inst)
    Branch(Bne) => branch_ne_mir_to_riscv(inst)
    Branch(Blt) => branch_lt_mir_to_riscv(inst)
    Branch(Bge) => branch_ge_mir_to_riscv(inst)
    Branch(Bltu) => branch_ltu_mir_to_riscv(inst)
    Branch(Bgeu) => branch_geu_mir_to_riscv(inst)
    Branch(Jmp) => jump_mir_to_riscv(inst)
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i32_add_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Add, 32), .. } else {
    println(
      "Compiler ICE: i32_add_mir_to_riscv called with non-i32 add instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Addw(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Addi(dst, src1, i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i64_add_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Add, 64), .. } else {
    println(
      "Compiler ICE: i32_add_mir_to_riscv called with non-i32 add instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Add(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Addi(dst, src1, i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i32_sub_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Sub, 32), .. } else {
    println(
      "Compiler ICE: i32_sub_mir_to_riscv called with non-i32 sub instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Subw(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Addi(dst, src1, -i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i64_sub_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Sub, 64), .. } else {
    println(
      "Compiler ICE: i64_sub_mir_to_riscv called with non-i64 sub instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Sub(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Addi(dst, src1, -i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i32_mul_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Mul, 32), .. } else {
    println(
      "Compiler ICE: i32_mul_mir_to_riscv called with non-i32 mul instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Mulw(dst, src1, src2)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i64_mul_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Mul, 64), .. } else {
    println(
      "Compiler ICE: i64_mul_mir_to_riscv called with non-i64 mul instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Mul(dst, src1, src2)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i32_div_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Div, 32), .. } else {
    println(
      "Compiler ICE: i32_div_mir_to_riscv called with non-i32 div instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Divw(dst, src1, src2)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i64_div_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Div, 64), .. } else {
    println(
      "Compiler ICE: i64_div_mir_to_riscv called with non-i64 div instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Div(dst, src1, src2)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i32_rem_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Rem, 32), .. } else {
    println(
      "Compiler ICE: i32_rem_mir_to_riscv called with non-i32 rem instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Remw(dst, src1, src2)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i64_rem_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Rem, 64), .. } else {
    println(
      "Compiler ICE: i64_rem_mir_to_riscv called with non-i64 rem instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Rem(dst, src1, src2)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn and_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(And, _), .. } else {
    println(
      "Compiler ICE: and_mir_to_riscv called with non-and instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [And(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Andi(dst, src1, i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn or_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Or, _), .. } else {
    println(
      "Compiler ICE: or_mir_to_riscv called with non-or instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Or(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Ori(dst, src1, i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn xor_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Xor, _), .. } else {
    println(
      "Compiler ICE: xor_mir_to_riscv called with non-xor instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Xor(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Xori(dst, src1, i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i32_shl_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Shl, 32), .. } else {
    println(
      "Compiler ICE: i32_shl_mir_to_riscv called with non-i32 shl instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Sllw(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Slli(dst, src1, i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i64_shl_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(Shl, 64), .. } else {
    println(
      "Compiler ICE: i64_shl_mir_to_riscv called with non-i64 shl instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Sll(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Slli(dst, src1, i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i32_lshr_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(LShr, 32), .. } else {
    println(
      "Compiler ICE: i32_lshr_mir_to_riscv called with non-i32 lshr instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Srlw(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Srli(dst, src1, i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i64_lshr_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IBinary(LShr, 64), .. } else {
    println(
      "Compiler ICE: i64_lshr_mir_to_riscv called with non-i64 lshr instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Srl(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Srli(dst, src1, i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i32_not_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IUnary(Not, 32), .. } else {
    println(
      "Compiler ICE: not_mir_to_riscv called with non-not instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Not(dst, src1)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i64_not_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IUnary(Not, 64), .. } else {
    println(
      "Compiler ICE: not_mir_to_riscv called with non-not instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Not(dst, src1)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn cmp_eq_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: ICmp(Eq, _), .. } else {
    println(
      "Compiler ICE: cmp_eq_mir_to_riscv called with non-eq instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Xor(dst, src1, src2), Seqz(dst, dst)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Xori(dst, src1, i2.to_int()), Seqz(dst, dst)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn cmp_ne_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: ICmp(Ne, _), .. } else {
    println(
      "Compiler ICE: cmp_ne_mir_to_riscv called with non-ne instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Xor(dst, src1, src2), Snez(dst, dst)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Xori(dst, src1, i2.to_int()), Snez(dst, dst)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn cmp_lt_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: ICmp(Lt, _), .. } else {
    println(
      "Compiler ICE: cmp_lt_mir_to_riscv called with non-lt instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Slt(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Slti(dst, src1, i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn cmp_gt_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: ICmp(Gt, _), .. } else {
    println(
      "Compiler ICE: cmp_gt_mir_to_riscv called with non-gt instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Slt(dst, src2, src1)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Slti(dst, src1, i2.to_int()), Xori(dst, dst, 1)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn cmp_ltu_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: ICmp(Ltu, _), .. } else {
    println(
      "Compiler ICE: cmp_ltu_mir_to_riscv called with non-ltu instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Sltu(dst, src1, src2)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Sltiu(dst, src1, i2.to_int())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn cmp_gtu_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: ICmp(Gtu, _), .. } else {
    println(
      "Compiler ICE: cmp_gtu_mir_to_riscv called with non-gtu instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Sltu(dst, src2, src1)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Sltiu(dst, src1, i2.to_int()), Xori(dst, dst, 1)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i32_load_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: ILoad(32), .. } else {
    println(
      "Compiler ICE: i32_load_mir_to_riscv called with non-i32 load instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [Mem(base, offset)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let base = Reg::from_mir_reg(base)
      let mem = Mem::{ base, offset }
      [Lw(dst, mem)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i64_load_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: ILoad(64), .. } else {
    println(
      "Compiler ICE: i64_load_mir_to_riscv called with non-i64 load instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [Mem(base, offset)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let base = Reg::from_mir_reg(base)
      let mem = Mem::{ base, offset }
      [Ld(dst, mem)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i32_store_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IStore(32), .. } else {
    println(
      "Compiler ICE: i32_store_mir_to_riscv called with non-i32 store instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [], uses: [IRegister(r), Mem(base, offset)], .. } => {
      let src = Reg::from_mir_reg(r)
      let base = Reg::from_mir_reg(base)
      let mem = Mem::{ base, offset }
      [Sw(src, mem)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn i64_store_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IStore(64), .. } else {
    println(
      "Compiler ICE: i64_store_mir_to_riscv called with non-i64 store instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [], uses: [IRegister(r), Mem(base, offset)], .. } => {
      let src = Reg::from_mir_reg(r)
      let base = Reg::from_mir_reg(base)
      let mem = Mem::{ base, offset }
      [Sd(src, mem)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn move_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: IMove(_), .. } else {
    println(
      "Compiler ICE: i32_move_mir_to_riscv called with non-i32 move instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src = Reg::from_mir_reg(r)
      [Mv(dst, src)]
    }
    // No need to consider i2 is too larget here, because MoonMIR has ensured that.
    { defs: [IRegister(d)], uses: [Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      [Li(dst, i2.to_string())]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn branch_eq_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: Branch(Beq), .. } else {
    println(
      "Compiler ICE: branch_eq_mir_to_riscv called with non-beq instruction: \{inst}",
    )
    panic()
  }
  match inst {
    {
      defs: [],
      uses: [
        IRegister(r1),
        IRegister(r2),
        Label(true_label),
        Label(false_label),
      ],
      ..,
    } => {
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Beq(src1, src2, true_label), J(false_label)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn branch_ne_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: Branch(Bne), .. } else {
    println(
      "Compiler ICE: branch_ne_mir_to_riscv called with non-bne instruction: \{inst}",
    )
    panic()
  }
  match inst {
    {
      defs: [],
      uses: [
        IRegister(r1),
        IRegister(r2),
        Label(true_label),
        Label(false_label),
      ],
      ..,
    } => {
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Bne(src1, src2, true_label), J(false_label)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn branch_lt_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: Branch(Blt), .. } else {
    println(
      "Compiler ICE: branch_lt_mir_to_riscv called with non-blt instruction: \{inst}",
    )
    panic()
  }
  match inst {
    {
      defs: [],
      uses: [
        IRegister(r1),
        IRegister(r2),
        Label(true_label),
        Label(false_label),
      ],
      ..,
    } => {
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Blt(src1, src2, true_label), J(false_label)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn branch_ge_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: Branch(Bge), .. } else {
    println(
      "Compiler ICE: branch_ge_mir_to_riscv called with non-bge instruction: \{inst}",
    )
    panic()
  }
  match inst {
    {
      defs: [],
      uses: [
        IRegister(r1),
        IRegister(r2),
        Label(true_label),
        Label(false_label),
      ],
      ..,
    } => {
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Bge(src1, src2, true_label), J(false_label)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn branch_ltu_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: Branch(Bltu), .. } else {
    println(
      "Compiler ICE: branch_ltu_mir_to_riscv called with non-bltu instruction: \{inst}",
    )
    panic()
  }
  match inst {
    {
      defs: [],
      uses: [
        IRegister(r1),
        IRegister(r2),
        Label(true_label),
        Label(false_label),
      ],
      ..,
    } => {
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Bltu(src1, src2, true_label), J(false_label)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn branch_geu_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: Branch(Bgeu), .. } else {
    println(
      "Compiler ICE: branch_geu_mir_to_riscv called with non-bgeu instruction: \{inst}",
    )
    panic()
  }
  match inst {
    {
      defs: [],
      uses: [
        IRegister(r1),
        IRegister(r2),
        Label(true_label),
        Label(false_label),
      ],
      ..,
    } => {
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Bgeu(src1, src2, true_label), J(false_label)]
    }
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}

///|
pub fn jump_mir_to_riscv(
  inst : @MoonMIR.Instruction,
) -> Array[RvAsm] raise MIRToRiscvError {
  guard inst is { opcode: Branch(Jmp), .. } else {
    println(
      "Compiler ICE: jump_mir_to_riscv called with non-jump instruction: \{inst}",
    )
    panic()
  }
  match inst {
    { defs: [], uses: [Label(target)], .. } => [J(target)]
    _ =>
      raise MIRToRiscvError("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}
