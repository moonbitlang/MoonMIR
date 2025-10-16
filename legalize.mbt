///|
pub fn Module::legalize(self : Self) -> Unit raise MIRError {
  self.functions.values().each(f => f.legalize())
}

///|
pub fn Function::legalize(func : Function) -> Unit raise MIRError {
  for bb in func.body {
    bb.legalize()
  }
}

///|
pub fn BasicBlock::legalize(self : BasicBlock) -> Unit raise MIRError {
  let new_insts : Array[Instruction] = Array::new()
  for inst in self.insts {
    inst.legalize().each(new_inst => new_insts.push(new_inst))
  }
  self.insts = new_insts
}

///|
pub fn Instruction::legalize(
  self : Instruction,
) -> Array[Instruction] raise MIRError {
  let { bb, func, .. } = self
  let builder = IRBuilder::new(func, bb)
  match self.opcode {
    IBinary(_) => self.legalize_ibinary(builder)
    IUnary(_) => self.legalize_iunary(builder)
    ICmp(_) => self.legalize_icmp(builder)
    ILoad(_) => self.legalize_iload(builder)
    IStore(_) => self.legalize_istore(builder)
    IMove(_) => self.legalize_imove(builder)
    Branch(_) => self.legalize_branch(builder)
    FBinary(_) => self.legalize_fbinary(builder)
    FUnary(_) => self.legalize_funary(builder)
    FCmp(_) => self.legalize_fcmp(builder)
    FLoad(_) => self.legalize_fload(builder)
    FStore(_) => self.legalize_fstore(builder)
    FMove(_) => self.legalize_fmove(builder)
    FMoveI(_) => self.legalize_fmovei(builder)
    IMoveF(_) => self.legalize_imovef(builder)
    Call => [self]
    Ret => [self]
    Nop => [self]
    Intrinsic(_) => raise LegalizeError("Unimplmented Intrinsic legalize Yet")
    _ => raise LegalizeError("Unimplmented Yet")
  }
}

///|
fn Instruction::legalize_ibinary(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: IBinary(binop, bits), .. } else {
    println(
      "Compiler ICE: calling legalize_ibinary on non-IBinary instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1), Mem(b2, o2)], .. } => {
      let v1 = func.new_virtual_reg()
      let v2 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_ibinary(binop, bits, dst=vdst, src1=v1, src2=v2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1), IRegister(r2)], .. } => {
      let v1 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_ibinary(binop, bits, dst=vdst, src1=v1, src2=r2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1), Imm(i2)], .. } => {
      let v1 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_ibinary_imm(binop, bits, dst=vdst, src1=v1, src2=i2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [IRegister(r1), Mem(b2, o2)], .. } => {
      let v2 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_ibinary(binop, bits, dst=vdst, src1=r1, src2=v2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_ibinary(binop, bits, dst=vdst, src1=r1, src2=r2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_ibinary_imm(binop, bits, dst=vdst, src1=r1, src2=i2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [Imm(i1), Mem(b2, o2)], .. } if binop.is_commutative() => {
      let v2 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_ibinary_imm(binop, bits, dst=vdst, src1=v2, src2=i1),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [Imm(i1), Mem(b2, o2)], .. } => {
      let v1 = func.new_virtual_reg()
      let v2 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_imove_imm(bits, dst=v1, src=i1),
        builder.build_ibinary(binop, bits, dst=vdst, src1=v1, src2=v2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [Imm(i1), IRegister(r2)], .. } if binop.is_commutative() => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_ibinary_imm(binop, bits, dst=vdst, src1=r2, src2=i1),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [Imm(i1), IRegister(r2)], .. } => {
      let v1 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=v1, src=i1),
        builder.build_ibinary(binop, bits, dst=vdst, src1=v1, src2=r2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [Imm(i1), Imm(i2)], .. } => {
      let i = match binop {
        Add => i1 + i2
        Sub => i1 - i2
        Mul => i1 * i2
        Div => i1 / i2
        Rem => i1 % i2
        And => i1 & i2
        Or => i1 | i2
        Xor => i1 ^ i2
        Shl => i1 << i2.to_int()
        LShr =>
          (i1.reinterpret_as_uint64() >> i2.to_int()).reinterpret_as_int64()
        AShr => i1 >> i2.to_int()
      }
      let vdst = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=vdst, src=i),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [IRegister(rdst)], uses: [Mem(b1, o1), Mem(b2, o2)], .. } => {
      let v1 = func.new_virtual_reg()
      let v2 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_ibinary(binop, bits, dst=rdst, src1=v1, src2=v2),
      ]
    }
    { defs: [IRegister(rdst)], uses: [Mem(b1, o1), IRegister(r2)], .. } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_ibinary(binop, bits, dst=rdst, src1=v1, src2=r2),
      ]
    }
    { defs: [IRegister(rdst)], uses: [Mem(b1, o1), Imm(i2)], .. } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_ibinary_imm(binop, bits, dst=rdst, src1=v1, src2=i2),
      ]
    }
    { defs: [IRegister(rdst)], uses: [IRegister(r1), Mem(b2, o2)], .. } => {
      let v2 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_ibinary(binop, bits, dst=rdst, src1=r1, src2=v2),
      ]
    }
    { defs: [IRegister(_)], uses: [IRegister(_), IRegister(_)], .. } => [self]
    { defs: [IRegister(_)], uses: [IRegister(_), Imm(_)], .. } => [self]
    {
      opcode: IBinary(binop, bits),
      defs: [IRegister(rdst)],
      uses: [Imm(i), IRegister(r2)],
      ..,
    } if binop.is_commutative() =>
      [builder.build_ibinary_imm(binop, bits, dst=rdst, src1=r2, src2=i)]
    { defs: [IRegister(rdst)], uses: [Imm(i), IRegister(r2)], .. } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=v1, src=i),
        builder.build_ibinary(binop, bits, dst=rdst, src1=v1, src2=r2),
      ]
    }
    _ => raise LegalizeError("Unhandled IBinary legalization case: \{self}")
  }
}

///|
pub fn Instruction::legalize_iunary(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: IUnary(unop, bits), .. } else {
    println(
      "Compiler ICE: calling legalize_iunary on non-IUnary instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1)], .. } => {
      let v1 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_iunary(unop, bits, dst=vdst, src=v1),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [IRegister(r1)], .. } => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_iunary(unop, bits, dst=vdst, src=r1),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [Imm(i1)], .. } => {
      let i = match unop {
        Not => i1.lnot()
      }
      let vdst = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=vdst, src=i),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [IRegister(rdst)], uses: [Mem(b1, o1)], .. } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_iunary(unop, bits, dst=rdst, src=v1),
      ]
    }
    { defs: [IRegister(_)], uses: [IRegister(_)], .. } => [self]
    { defs: [IRegister(rdst)], uses: [Imm(i1)], .. } => {
      let i = match unop {
        Not => i1.lnot()
      }
      let vdst = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=vdst, src=i),
        builder.build_imove(bits, dst=rdst, src=vdst),
      ]
    }
    _ => raise LegalizeError("Unhandled IUnary legalization case: \{self}")
  }
}

///|
pub fn Instruction::legalize_icmp(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: ICmp(_, _), .. } else {
    println(
      "Compiler ICE: calling legalize_icmp on non-ICmp instruction: \{self}",
    )
    panic()
  }
  match self {
    {
      opcode: ICmp(cmpop, bits),
      defs: [Mem(base, offset)],
      uses: [Mem(b1, o1), Mem(b2, o2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let v2 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_icmp(cmpop, bits, dst=vdst, src1=v1, src2=v2),
        builder.build_storei(32, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: ICmp(cmpop, bits),
      defs: [Mem(base, offset)],
      uses: [Mem(b1, o1), IRegister(r2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_icmp(cmpop, bits, dst=vdst, src1=v1, src2=r2),
        builder.build_storei(32, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: ICmp(cmpop, bits),
      defs: [Mem(base, offset)],
      uses: [Mem(b1, o1), Imm(i2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let v2 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_imove_imm(bits, dst=v2, src=i2),
        builder.build_icmp(cmpop, bits, dst=vdst, src1=v1, src2=v2),
        builder.build_storei(32, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: ICmp(cmpop, bits),
      defs: [Mem(base, offset)],
      uses: [IRegister(r1), Mem(b2, o2)],
      ..,
    } => {
      let v2 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_icmp(cmpop, bits, dst=vdst, src1=r1, src2=v2),
        builder.build_storei(32, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: ICmp(cmpop, bits),
      defs: [Mem(base, offset)],
      uses: [IRegister(r1), IRegister(r2)],
      ..,
    } => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_icmp(cmpop, bits, dst=vdst, src1=r1, src2=r2),
        builder.build_storei(32, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: ICmp(cmpop, bits),
      defs: [Mem(base, offset)],
      uses: [IRegister(r1), Imm(i2)],
      ..,
    } => {
      let v2 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=v2, src=i2),
        builder.build_icmp(cmpop, bits, dst=vdst, src1=r1, src2=v2),
        builder.build_storei(32, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: ICmp(cmpop, bits),
      defs: [IRegister(rdst)],
      uses: [Mem(b1, o1), Mem(b2, o2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let v2 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_icmp(cmpop, bits, dst=rdst, src1=v1, src2=v2),
      ]
    }
    {
      opcode: ICmp(cmpop, bits),
      defs: [IRegister(rdst)],
      uses: [Mem(b1, o1), IRegister(r2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_icmp(cmpop, bits, dst=rdst, src1=v1, src2=r2),
      ]
    }
    {
      opcode: ICmp(cmpop, bits),
      defs: [IRegister(rdst)],
      uses: [Mem(b1, o1), Imm(i2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let v2 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_imove_imm(bits, dst=v2, src=i2),
        builder.build_icmp(cmpop, bits, dst=rdst, src1=v1, src2=v2),
      ]
    }
    {
      opcode: ICmp(cmpop, bits),
      defs: [IRegister(rdst)],
      uses: [IRegister(r1), Mem(b2, o2)],
      ..,
    } => {
      let v2 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_icmp(cmpop, bits, dst=rdst, src1=r1, src2=v2),
      ]
    }
    {
      opcode: ICmp(_, _),
      defs: [IRegister(_)],
      uses: [IRegister(_), IRegister(_)],
      ..,
    } => [self]
    {
      opcode: ICmp(cmpop, bits),
      defs: [IRegister(rdst)],
      uses: [IRegister(r1), Imm(i2)],
      ..,
    } => {
      let v2 = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=v2, src=i2),
        builder.build_icmp(cmpop, bits, dst=rdst, src1=r1, src2=v2),
      ]
    }
    _ => raise LegalizeError("Unhandled ICmp legalization case: \{self}")
  }
}

///|
pub fn Instruction::legalize_iload(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: ILoad(bits), .. } else {
    println(
      "Compiler ICE: calling legalize_iload on non-ILoad instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1)], .. } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_storei(bits, src=v1, base~, offset~),
      ]
    }
    { defs: [IRegister(_)], uses: [Mem(_)], .. } as inst => [inst]
    _ => raise LegalizeError("Unhandled ILoad legalization case: \{self}")
  }
}

///|
pub fn Instruction::legalize_istore(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: IStore(bits), .. } else {
    println(
      "Compiler ICE: calling legalize_istore on non-IStore instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [], uses: [Mem(base, offset), Mem(b1, o1)], .. } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_storei(bits, src=v1, base~, offset~),
      ]
    }
    { defs: [], uses: [Mem(_), IRegister(_)], .. } as inst => [inst]
    _ => raise LegalizeError("Unhandled IStore legalization case: \{self}")
  }
}

///|
pub fn Instruction::legalize_imove(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: IMove(bits), .. } else {
    println(
      "Compiler ICE: calling legalize_imove on non-IMove instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1)], .. } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_storei(bits, src=v1, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [Imm(i1)], .. } => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=vdst, src=i1),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [IRegister(d)], uses: [IRegister(s)], .. } if d == s => []
    { defs: [IRegister(_)], uses: [IRegister(_)], .. } as inst => [inst]
    { defs: [IRegister(_)], uses: [Imm(_)], .. } as inst => [inst]
    _ => raise LegalizeError("Unhandled IMove legalization case: \{self}")
  }
}

///|
pub fn Instruction::legalize_branch(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: Branch(bop), .. } else {
    println(
      "Compiler ICE: calling legalize_branch on non-IBranch instruction: \{self}",
    )
    panic()
  }
  match self {
    {
      defs: [],
      uses: [Mem(b1, o1), Mem(b2, o2), Label(true_label), Label(false_label)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let v2 = func.new_virtual_reg()
      [
        builder.build_loadi(32, dst=v1, base=b1, offset=o1),
        builder.build_loadi(32, dst=v2, base=b2, offset=o2),
        builder.build_branch(bop, lhs=v1, rhs=v2, true_label~, false_label~),
      ]
    }
    {
      defs: [],
      uses: [Mem(b1, o1), IRegister(r2), Label(true_label), Label(false_label)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(32, dst=v1, base=b1, offset=o1),
        builder.build_branch(bop, lhs=v1, rhs=r2, true_label~, false_label~),
      ]
    }
    {
      defs: [],
      uses: [Mem(b1, o1), Imm(v2), Label(true_label), Label(false_label)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(32, dst=v1, base=b1, offset=o1),
        builder.build_branch_imm(bop, lhs=v1, rhs=v2, true_label~, false_label~),
      ]
    }
    {
      defs: [],
      uses: [IRegister(r1), Mem(b2, o2), Label(true_label), Label(false_label)],
      ..,
    } => {
      let v2 = func.new_virtual_reg()
      [
        builder.build_loadi(32, dst=v2, base=b2, offset=o2),
        builder.build_branch(bop, lhs=r1, rhs=v2, true_label~, false_label~),
      ]
    }
    { defs: [], uses: [IRegister(_), IRegister(_), Label(_), Label(_)], .. } as inst =>
      [inst]
    { defs: [], uses: [IRegister(_), Imm(_), Label(_), Label(_)], .. } as inst =>
      [inst]
    {
      defs: [],
      uses: [Imm(i1), Mem(b2, o2), Label(true_label), Label(false_label)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let v2 = func.new_virtual_reg()
      [
        builder.build_loadi(32, dst=v2, base=b2, offset=o2),
        builder.build_imove_imm(32, dst=v1, src=i1),
        builder.build_branch(bop, lhs=v1, rhs=v2, true_label~, false_label~),
      ]
    }
    {
      defs: [],
      uses: [Imm(i1), IRegister(r2), Label(true_label), Label(false_label)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_imove_imm(32, dst=v1, src=i1),
        builder.build_branch(bop, lhs=v1, rhs=r2, true_label~, false_label~),
      ]
    }
    {
      defs: [],
      uses: [Imm(i1), Imm(i2), Label(true_label), Label(false_label)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let v2 = func.new_virtual_reg()
      [
        builder.build_imove_imm(32, dst=v1, src=i1),
        builder.build_imove_imm(32, dst=v2, src=i2),
        builder.build_branch(bop, lhs=v1, rhs=v2, true_label~, false_label~),
      ]
    }
    { defs: [], uses: [Label(_)], .. } as inst => [inst]
    _ => raise LegalizeError("Unhandled IBranch legalization case: \{self}")
  }
}

//
// Note: fbinary is not support fimm operand, if it happens, raise error

///|
pub fn Instruction::legalize_fbinary(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: FBinary(binop, bits), .. } else {
    println(
      "Compiler ICE: calling legalize_fbinary on non-FBinary instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1), Mem(b2, o2)], .. } => {
      let v1 = func.new_virtual_freg()
      let v2 = func.new_virtual_freg()
      let vdst = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_loadf(bits, dst=v2, base=b2, offset=o2),
        builder.build_fbinary(binop, bits, dst=vdst, src1=v1, src2=v2),
        builder.build_storef(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1), FRegister(r2)], .. } => {
      let v1 = func.new_virtual_freg()
      let vdst = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_fbinary(binop, bits, dst=vdst, src1=v1, src2=r2),
        builder.build_storef(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [FRegister(r1), Mem(b2, o2)], .. } => {
      let v2 = func.new_virtual_freg()
      let vdst = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v2, base=b2, offset=o2),
        builder.build_fbinary(binop, bits, dst=vdst, src1=r1, src2=v2),
        builder.build_storef(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [FRegister(r1), FRegister(r2)], .. } => {
      let vdst = func.new_virtual_freg()
      [
        builder.build_fbinary(binop, bits, dst=vdst, src1=r1, src2=r2),
        builder.build_storef(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [FRegister(rdst)], uses: [Mem(b1, o1), Mem(b2, o2)], .. } => {
      let v1 = func.new_virtual_freg()
      let v2 = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_loadf(bits, dst=v2, base=b2, offset=o2),
        builder.build_fbinary(binop, bits, dst=rdst, src1=v1, src2=v2),
      ]
    }
    { defs: [FRegister(rdst)], uses: [Mem(b1, o1), FRegister(r2)], .. } => {
      let v1 = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_fbinary(binop, bits, dst=rdst, src1=v1, src2=r2),
      ]
    }
    { defs: [FRegister(rdst)], uses: [FRegister(r1), Mem(b2, o2)], .. } => {
      let v2 = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v2, base=b2, offset=o2),
        builder.build_fbinary(binop, bits, dst=rdst, src1=r1, src2=v2),
      ]
    }
    { defs: [FRegister(_)], uses: [FRegister(_), FRegister(_)], .. } as inst =>
      [inst]
    _ => raise LegalizeError("Unhandled FBinary legalization case: \{self}")
  }
}

///|
pub fn Instruction::legalize_funary(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: FUnary(unop, bits), .. } else {
    println(
      "Compiler ICE: calling legalize_funary on non-FUnary instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1)], .. } => {
      let v1 = func.new_virtual_freg()
      let vdst = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_funary(unop, bits, dst=vdst, src=v1),
        builder.build_storef(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [FRegister(r1)], .. } => {
      let vdst = func.new_virtual_freg()
      [
        builder.build_funary(unop, bits, dst=vdst, src=r1),
        builder.build_storef(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [FRegister(rdst)], uses: [Mem(b1, o1)], .. } => {
      let v1 = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_funary(unop, bits, dst=rdst, src=v1),
      ]
    }
    { defs: [FRegister(_)], uses: [FRegister(_)], .. } as inst => [inst]
    _ => raise LegalizeError("Unhandled FUnary legalization case: \{self}")
  }
}

///|
pub fn Instruction::legalize_fcmp(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: FCmp(fcmpop, bits), .. } else {
    println(
      "Compiler ICE: calling legalize_fcmp on non-FCmp instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1), Mem(b2, o2)], .. } => {
      let v1 = func.new_virtual_freg()
      let v2 = func.new_virtual_freg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_loadf(bits, dst=v2, base=b2, offset=o2),
        builder.build_fcmp(fcmpop, bits, dst=vdst, src1=v1, src2=v2),
        builder.build_storei(32, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1), FRegister(r2)], .. } => {
      let v1 = func.new_virtual_freg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_fcmp(fcmpop, bits, dst=vdst, src1=v1, src2=r2),
        builder.build_storei(32, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [FRegister(r1), Mem(b2, o2)], .. } => {
      let v2 = func.new_virtual_freg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadf(bits, dst=v2, base=b2, offset=o2),
        builder.build_fcmp(fcmpop, bits, dst=vdst, src1=r1, src2=v2),
        builder.build_storei(32, src=vdst, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [FRegister(r1), FRegister(r2)], .. } => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_fcmp(fcmpop, bits, dst=vdst, src1=r1, src2=r2),
        builder.build_storei(32, src=vdst, base~, offset~),
      ]
    }
    { defs: [IRegister(rdst)], uses: [Mem(b1, o1), Mem(b2, o2)], .. } => {
      let v1 = func.new_virtual_freg()
      let v2 = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_loadf(bits, dst=v2, base=b2, offset=o2),
        builder.build_fcmp(fcmpop, bits, dst=rdst, src1=v1, src2=v2),
      ]
    }
    { defs: [IRegister(rdst)], uses: [Mem(b1, o1), FRegister(r2)], .. } => {
      let v1 = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_fcmp(fcmpop, bits, dst=rdst, src1=v1, src2=r2),
      ]
    }
    { defs: [IRegister(rdst)], uses: [FRegister(r1), Mem(b2, o2)], .. } => {
      let v2 = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v2, base=b2, offset=o2),
        builder.build_fcmp(fcmpop, bits, dst=rdst, src1=r1, src2=v2),
      ]
    }
    { defs: [IRegister(_)], uses: [IRegister(_), IRegister(_)], .. } as inst =>
      [inst]
    _ => raise LegalizeError("Unhandled FCmp legalization case: \{self}")
  }
}

//FLoad(_) => self.legalize_fload(builder)
//FStore(_) => self.legalize_fstore(builder)
//FMove(_) => self.legalize_fmove(builder)
//FMoveI(_) => self.legalize_fmovei(builder)
//IMoveF(_) => self.legalize_imovef(builder)

///|
pub fn Instruction::legalize_fload(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: FLoad(bits), .. } else {
    println(
      "Compiler ICE: calling legalize_fload on non-FLoad instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1)], .. } => {
      let v1 = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_storef(bits, src=v1, base~, offset~),
      ]
    }
    { defs: [FRegister(_)], uses: [Mem(_)], .. } as inst => [inst]
    _ => raise LegalizeError("Unhandled FLoad legalization case: \{self}")
  }
}

///|
pub fn Instruction::legalize_fstore(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: FStore(bits), .. } else {
    println(
      "Compiler ICE: calling legalize_fstore on non-FStore instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1)], .. } => {
      let v1 = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_storef(bits, src=v1, base~, offset~),
      ]
    }
    { defs: [Mem(_)], uses: [FRegister(_)], .. } as inst => [inst]
    _ => raise LegalizeError("Unhandled FStore legalization case: \{self}")
  }
}

///|
pub fn Instruction::legalize_fmove(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: FMove(bits), .. } else {
    println(
      "Compiler ICE: calling legalize_fmove on non-FMove instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [Mem(b1, o1)], .. } => {
      let v1 = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base=b1, offset=o1),
        builder.build_storef(bits, src=v1, base~, offset~),
      ]
    }
    { defs: [Mem(base, offset)], uses: [FRegister(r1)], .. } => {
      let vdst = func.new_virtual_freg()
      [
        builder.build_fmove(bits, dst=vdst, src=r1),
        builder.build_storef(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [FRegister(_)], uses: [FRegister(_)], .. } as inst => [inst]
    { defs: [FRegister(_)], uses: [Mem(base, offset)], .. } => {
      let v1 = func.new_virtual_freg()
      [
        builder.build_loadf(bits, dst=v1, base~, offset~),
        builder.build_fmove(bits, dst=func.new_virtual_freg(), src=v1),
      ]
    }
    _ => raise LegalizeError("Unhandled FMove legalization case: \{self}")
  }
}

///|
pub fn Instruction::legalize_fmovei(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: FMoveI(bits), .. } else {
    println(
      "Compiler ICE: calling legalize_fmovei on non-FMoveI instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [IRegister(r1)], .. } => {
      let v1 = func.new_virtual_reg()
      let vdst = func.new_virtual_freg()
      [
        builder.build_imove(bits, dst=v1, src=r1),
        builder.build_fmove_from_ireg(bits, dst=vdst, src=v1),
        builder.build_storef(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [FRegister(_)], uses: [IRegister(_)], .. } as inst => [inst]
    { defs: [FRegister(_)], uses: [Mem(base, offset)], .. } => {
      let v1 = func.new_virtual_reg()
      let vdst = func.new_virtual_freg()
      [
        builder.build_loadi(bits, dst=v1, base~, offset~),
        builder.build_fmove_from_ireg(bits, dst=vdst, src=v1),
      ]
    }
    _ => raise LegalizeError("Unhandled FMoveI legalization case: \{self}")
  }
}

// imovef means move from freg to ireg

///|
pub fn Instruction::legalize_imovef(
  self : Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let { func, .. } = builder
  guard self is { opcode: IMoveF(bits), .. } else {
    println(
      "Compiler ICE: calling legalize_imovef on non-IMoveF instruction: \{self}",
    )
    panic()
  }
  match self {
    { defs: [Mem(base, offset)], uses: [FRegister(r1)], .. } => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_fmove_to_ireg(bits, dst=vdst, src=r1),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    { defs: [IRegister(_)], uses: [FRegister(_)], .. } as inst => [inst]
    { defs: [IRegister(_)], uses: [Mem(base, offset)], .. } => {
      let v1 = func.new_virtual_freg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadf(bits, dst=v1, base~, offset~),
        builder.build_fmove_to_ireg(bits, dst=vdst, src=v1),
      ]
    }
    _ => raise LegalizeError("Unhandled IMoveF legalization case: \{self}")
  }
}
