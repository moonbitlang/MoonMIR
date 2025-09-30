///|
pub fn Module::legalize(self : Self) -> Unit raise MIRError {
  self.functions.each(f => f.legalize())
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
  match self {
    {
      opcode: IBinary(binop, bits),
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
        builder.build_ibinary(binop, bits, dst=vdst, src1=v1, src2=v2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [Mem(base, offset)],
      uses: [Mem(b1, o1), IRegister(r2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_ibinary(binop, bits, dst=vdst, src1=v1, src2=r2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [Mem(base, offset)],
      uses: [Mem(b1, o1), Imm(i2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_ibinary_imm(binop, bits, dst=vdst, src1=v1, src2=i2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [Mem(base, offset)],
      uses: [IRegister(r1), Mem(b2, o2)],
      ..,
    } => {
      let v2 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_ibinary(binop, bits, dst=vdst, src1=r1, src2=v2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [Mem(base, offset)],
      uses: [IRegister(r1), IRegister(r2)],
      ..,
    } => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_ibinary(binop, bits, dst=vdst, src1=r1, src2=r2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [Mem(base, offset)],
      uses: [IRegister(r1), Imm(i2)],
      ..,
    } => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_ibinary_imm(binop, bits, dst=vdst, src1=r1, src2=i2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [Mem(base, offset)],
      uses: [Imm(i1), Mem(b2, o2)],
      ..,
    } if binop.is_commutative() => {
      let v2 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_ibinary_imm(binop, bits, dst=vdst, src1=v2, src2=i1),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [Mem(base, offset)],
      uses: [Imm(i1), Mem(b2, o2)],
      ..,
    } => {
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
    {
      opcode: IBinary(binop, bits),
      defs: [Mem(base, offset)],
      uses: [Imm(i1), IRegister(r2)],
      ..,
    } if binop.is_commutative() => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_ibinary_imm(binop, bits, dst=vdst, src1=r2, src2=i1),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [Mem(base, offset)],
      uses: [Imm(i1), IRegister(r2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=v1, src=i1),
        builder.build_ibinary(binop, bits, dst=vdst, src1=v1, src2=r2),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [Mem(base, offset)],
      uses: [Imm(i1), Imm(i2)],
      ..,
    } => {
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
    {
      opcode: IBinary(binop, bits),
      defs: [IRegister(rdst)],
      uses: [Mem(b1, o1), Mem(b2, o2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let v2 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_ibinary(binop, bits, dst=rdst, src1=v1, src2=v2),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [IRegister(rdst)],
      uses: [Mem(b1, o1), IRegister(r2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_ibinary(binop, bits, dst=rdst, src1=v1, src2=r2),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [IRegister(rdst)],
      uses: [Mem(b1, o1), Imm(i2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_ibinary_imm(binop, bits, dst=rdst, src1=v1, src2=i2),
      ]
    }
    {
      opcode: IBinary(binop, bits),
      defs: [IRegister(rdst)],
      uses: [IRegister(r1), Mem(b2, o2)],
      ..,
    } => {
      let v2 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v2, base=b2, offset=o2),
        builder.build_ibinary(binop, bits, dst=rdst, src1=r1, src2=v2),
      ]
    }
    {
      opcode: IBinary(_),
      defs: [IRegister(_)],
      uses: [IRegister(_), IRegister(_)],
      ..,
    } => [self]
    {
      opcode: IBinary(_),
      defs: [IRegister(_)],
      uses: [IRegister(_), Imm(_)],
      ..,
    } => [self]
    {
      opcode: IBinary(binop, bits),
      defs: [IRegister(rdst)],
      uses: [Imm(i), IRegister(r2)],
      ..,
    } if binop.is_commutative() =>
      [builder.build_ibinary_imm(binop, bits, dst=rdst, src1=r2, src2=i)]
    {
      opcode: IBinary(binop, bits),
      defs: [IRegister(rdst)],
      uses: [Imm(i), IRegister(r2)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=v1, src=i),
        builder.build_ibinary(binop, bits, dst=rdst, src1=v1, src2=r2),
      ]
    }
    { opcode: IBinary(_), .. } =>
      raise LegalizeError("Unhandled IBinary legalization case: \{self}")
    {
      opcode: IUnary(unop, bits),
      defs: [Mem(base, offset)],
      uses: [Mem(b1, o1)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      let vdst = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_iunary(unop, bits, dst=vdst, src=v1),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IUnary(unop, bits),
      defs: [Mem(base, offset)],
      uses: [IRegister(r1)],
      ..,
    } => {
      let vdst = func.new_virtual_reg()
      [
        builder.build_iunary(unop, bits, dst=vdst, src=r1),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IUnary(unop, bits),
      defs: [Mem(base, offset)],
      uses: [Imm(i1)],
      ..,
    } => {
      let i = match unop {
        Not => i1.lnot()
      }
      let vdst = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=vdst, src=i),
        builder.build_storei(bits, src=vdst, base~, offset~),
      ]
    }
    {
      opcode: IUnary(unop, bits),
      defs: [IRegister(rdst)],
      uses: [Mem(b1, o1)],
      ..,
    } => {
      let v1 = func.new_virtual_reg()
      [
        builder.build_loadi(bits, dst=v1, base=b1, offset=o1),
        builder.build_iunary(unop, bits, dst=rdst, src=v1),
      ]
    }
    { opcode: IUnary(_), defs: [IRegister(_)], uses: [IRegister(_)], .. } =>
      [self]
    { opcode: IUnary(unop, bits), defs: [IRegister(rdst)], uses: [Imm(i1)], .. } => {
      let i = match unop {
        Not => i1.lnot()
      }
      let vdst = func.new_virtual_reg()
      [
        builder.build_imove_imm(bits, dst=vdst, src=i),
        builder.build_imove(bits, dst=rdst, src=vdst),
      ]
    }
    { opcode: IUnary(_), .. } =>
      raise LegalizeError("Unhandled IUnary legalization case: \{self}")
    _ => raise LegalizeError("Unimplmented Yet")
  }
}
