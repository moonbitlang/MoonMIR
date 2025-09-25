///|
pub suberror GMIRToRvAsmError String derive(Show)

///|
#callsite(autofill(loc))
pub fn Reg::from_mir_operand(v : @GMIR.Operand, loc~ : SourceLoc) -> Reg raise {
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
      raise GMIRToRvAsmError(
        "Error: Unsupported GMIR register: \{v}, loc: \{loc}",
      )
  }
}

///|
pub fn FReg::from_mir_operand(v : @GMIR.Operand) -> FReg raise {
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
      raise GMIRToRvAsmError(
        "Error: Unsupported GMIR floating-point register: \{v}",
      )
  }
}

///|
fn get_free_reg(inst : @GMIR.Instruction) -> Array[Reg] raise {
  let all_regs : Set[@GMIR.Operand] = Set::of([
    AReg(0),
    AReg(1),
    AReg(2),
    AReg(3),
    AReg(4),
    AReg(5),
    AReg(6),
    AReg(7),
    TReg(0),
    TReg(1),
    TReg(2),
    TReg(3),
    TReg(4),
    TReg(5),
    TReg(6),
    SReg(0),
    SReg(1),
    SReg(2),
    SReg(3),
    SReg(4),
    SReg(5),
    SReg(6),
    SReg(7),
    SReg(8),
    SReg(9),
    SReg(10),
  ])
  let { liveout, uses, .. } = inst
  for op in liveout {
    match op {
      AReg(_) | TReg(_) | SReg(_) as op => all_regs.remove(op)
      _ => ()
    }
  }
  for op in uses {
    match op {
      AReg(_) | TReg(_) | SReg(_) as op => all_regs.remove(op)
      _ => ()
    }
  }
  let free_regs : Array[Reg] = Array::new()
  for op in all_regs {
    if op is AReg(_) {
      free_regs.push(Reg::from_mir_operand(op))
    }
  }
  for op in all_regs {
    if op is TReg(_) {
      free_regs.push(Reg::from_mir_operand(op))
    }
  }
  for op in all_regs {
    if op is SReg(_) {
      free_regs.push(Reg::from_mir_operand(op))
    }
  }
  free_regs
}

///|
pub fn from_gmir_inst(inst : @GMIR.Instruction) -> Array[RvAsm] raise {
  match inst {
    { opcode: Addl, defs: [dst], uses: [src1, Imm(src2)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      [Addi(dst, src1, src2.to_int())]
    }
    { opcode: Addl, defs: [dst], uses: [src1, src2], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      let src2 = Reg::from_mir_operand(src2)
      [Addw(dst, src1, src2)]
    }
    { opcode: Addq, defs: [dst], uses: [src1, Imm(src2)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      [Addi(dst, src1, src2.to_int())]
    }
    { opcode: Addq, defs: [dst], uses: [src1, src2], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      let src2 = Reg::from_mir_operand(src2)
      [Add(dst, src1, src2)]
    }
    { opcode: Subl, defs: [dst], uses: [src1, Imm(src2)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      [Addi(dst, src1, -src2.to_int())]
    }
    { opcode: Subl, defs: [dst], uses: [src1, src2], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      let src2 = Reg::from_mir_operand(src2)
      [Subw(dst, src1, src2)]
    }
    { opcode: Subq, defs: [dst], uses: [src1, Imm(src2)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      [Addi(dst, src1, -src2.to_int())]
    }
    { opcode: Subq, defs: [dst], uses: [src1, src2], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      let src2 = Reg::from_mir_operand(src2)
      [Sub(dst, src1, src2)]
    }
    { opcode: Mull, defs: [dst], uses: [src1, Imm(src2)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      let free_regs = get_free_reg(inst)
      let temp_reg = free_regs
        .get(0)
        .unwrap_or_else(fn() raise {
          raise GMIRToRvAsmError(
            "No free register available for Mull immediate",
          )
        })
      [Li(temp_reg, src2.to_string()), Mulw(dst, src1, temp_reg)]
    }
    { opcode: Mull, defs: [dst], uses: [src1, src2], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      let src2 = Reg::from_mir_operand(src2)
      [Mulw(dst, src1, src2)]
    }
    { opcode: Mulq, defs: [dst], uses: [src1, Imm(src2)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      let free_regs = get_free_reg(inst)
      let temp_reg = free_regs
        .get(0)
        .unwrap_or_else(fn() raise {
          raise GMIRToRvAsmError(
            "No free register available for Mulq immediate",
          )
        })
      [Li(temp_reg, src2.to_string()), Mul(dst, src1, temp_reg)]
    }
    { opcode: Mulq, defs: [dst], uses: [src1, src2], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      let src2 = Reg::from_mir_operand(src2)
      [Mul(dst, src1, src2)]
    }
    { opcode: Movq, defs: [dst], uses: [Label(addr)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      [LuiHi(dst, addr), AddiLo(dst, dst, addr)]
    }
    { opcode: Movq, defs: [dst], uses: [Imm(i)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      [Li(dst, i.to_string())]
    }
    { opcode: Movq, defs: [dst], uses: [src], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src = Reg::from_mir_operand(src)
      [Mv(dst, src)]
    }
    { opcode: Movl, defs: [dst], uses: [Imm(i)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      [Li(dst, i.to_string())]
    }
    { opcode: Movl, defs: [dst], uses: [src], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src = Reg::from_mir_operand(src)
      [Mv(dst, src)]
    }
    { opcode: Ret, defs: [], uses: [], .. } => [Ret]
    { opcode: Storew, defs: [], uses: [Mem(base, offset), Imm(i)], .. } => {
      // riscv doesn't support store immediate, need to use a temp register
      let base = Reg::from_mir_operand(base)
      let free_regs = get_free_reg(inst)
      let free_reg = free_regs
        .get(0)
        .unwrap_or_else(fn() raise {
          raise GMIRToRvAsmError("No free register available")
        })
      let insts : Array[RvAsm] = Array::new()
      insts.push(Li(free_reg, i.to_string()))
      insts.push(Sh(free_reg, Mem::{ base, offset }))
      insts
    }
    { opcode: Storew, defs: [], uses: [Mem(base, offset), src], .. } => {
      let base = Reg::from_mir_operand(base)
      let src = Reg::from_mir_operand(src)
      [Sh(src, Mem::{ base, offset })]
    }
    { opcode: Storel, defs: [], uses: [Mem(base, offset), Imm(i)], .. } => {
      // riscv doesn't support store immediate, need to use a temp register
      let base = Reg::from_mir_operand(base)
      let free_regs = get_free_reg(inst)
      let free_reg = free_regs
        .get(0)
        .unwrap_or_else(fn() raise {
          raise GMIRToRvAsmError("No free register available")
        })
      let insts : Array[RvAsm] = Array::new()
      insts.push(Li(free_reg, i.to_string()))
      insts.push(Sw(free_reg, Mem::{ base, offset }))
      insts
    }
    {
      opcode: Storel,
      defs: [],
      uses: [Mem(base1, offset1), Mem(base2, offset2)],
      ..,
    } => {
      // riscv doesn't support store from memory to memory, need to use a temp register
      let base1 = Reg::from_mir_operand(base1)
      let base2 = Reg::from_mir_operand(base2)
      let free_regs = get_free_reg(inst)
      let free_reg = free_regs
        .get(0)
        .unwrap_or_else(fn() raise {
          raise GMIRToRvAsmError("No free register available")
        })
      let insts : Array[RvAsm] = Array::new()
      insts.push(Lw(free_reg, Mem::{ base: base2, offset: offset2 }))
      insts.push(Sw(free_reg, Mem::{ base: base1, offset: offset1 }))
      insts
    }
    { opcode: Storel, defs: [], uses: [Mem(base, offset), src], .. } => {
      let base = Reg::from_mir_operand(base)
      let src = Reg::from_mir_operand(src)
      [Sw(src, Mem::{ base, offset })]
    }
    { opcode: Loadw, defs: [dst], uses: [Mem(base, offset)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let base = Reg::from_mir_operand(base)
      [Lh(dst, Mem::{ base, offset })]
    }
    { opcode: Loadl, defs: [dst], uses: [Mem(base, offset)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let base = Reg::from_mir_operand(base)
      [Lw(dst, Mem::{ base, offset })]
    }
    { opcode: Storeq, defs: [], uses: [Mem(base, offset), Imm(i)], .. } => {
      // riscv doesn't support store immediate, need to use a temp register
      let base = Reg::from_mir_operand(base)
      let free_regs = get_free_reg(inst)
      let free_reg = free_regs
        .get(0)
        .unwrap_or_else(fn() raise {
          raise GMIRToRvAsmError("No free register available")
        })
      let insts : Array[RvAsm] = Array::new()
      insts.push(Li(free_reg, i.to_string()))
      insts.push(Sd(free_reg, Mem::{ base, offset }))
      insts
    }
    { opcode: Storeq, defs: [], uses: [Mem(base, offset), src], .. } => {
      let base = Reg::from_mir_operand(base)
      let src = Reg::from_mir_operand(src)
      [Sd(src, Mem::{ base, offset })]
    }
    { opcode: Loadq, defs: [dst], uses: [Mem(base, offset)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let base = Reg::from_mir_operand(base)
      [Ld(dst, Mem::{ base, offset })]
    }
    { opcode: Call, defs: [], uses: [Label(func_name)], .. } =>
      [Call(func_name)]
    {
      opcode: Bgt,
      defs: [],
      uses: [src1, Imm(imm), Label(label1), Label(label2)],
      ..,
    } => {
      let src1 = Reg::from_mir_operand(src1)
      let free_regs = get_free_reg(inst)
      let temp_reg = free_regs
        .get(0)
        .unwrap_or_else(fn() raise {
          raise GMIRToRvAsmError("No free register available for Bgt immediate")
        })
      [Li(temp_reg, imm.to_string()), Bgt(src1, temp_reg, label1), J(label2)]
    }
    {
      opcode: Bgt,
      defs: [],
      uses: [src1, src2, Label(label1), Label(label2)],
      ..,
    } => {
      let src1 = Reg::from_mir_operand(src1)
      let src2 = Reg::from_mir_operand(src2)
      [Bgt(src1, src2, label1), J(label2)]
    }
    {
      opcode: Blt,
      defs: [],
      uses: [src1, Imm(imm), Label(label1), Label(label2)],
      ..,
    } => {
      let src1 = Reg::from_mir_operand(src1)
      let free_regs = get_free_reg(inst)
      let temp_reg = free_regs
        .get(0)
        .unwrap_or_else(fn() raise {
          raise GMIRToRvAsmError("No free register available for Blt immediate")
        })
      [Li(temp_reg, imm.to_string()), Blt(src1, temp_reg, label1), J(label2)]
    }
    {
      opcode: Blt,
      defs: [],
      uses: [src1, src2, Label(label1), Label(label2)],
      ..,
    } => {
      let src1 = Reg::from_mir_operand(src1)
      let src2 = Reg::from_mir_operand(src2)
      [Blt(src1, src2, label1), J(label2)]
    }
    { opcode: Jmp, defs: [], uses: [Label(label)], .. } => [J(label)]
    _ => raise GMIRToRvAsmError("UnImplemented GMIR instruction: \{inst}")
  }
}

///|
pub fn from_gmir_bb(bb : @GMIR.BasicBlock, i : Int) -> Array[RvAsm] raise {
  let insts : Array[RvAsm] = Array::new()
  let label = bb.label
  if i != 0 { // For Entry block, no need to add label
    insts.push(Label(label))
  }
  bb.insts.each(inst => insts.append(from_gmir_inst(inst)))
  insts
}

///|
pub fn from_gmir_func(func : @GMIR.Function) -> Array[RvAsm] raise {
  let insts : Array[RvAsm] = Array::new()
  let fname = func.name
  insts.push(Label(fname))
  for i, bb in func.body {
    let bb_insts = from_gmir_bb(bb, i)
    insts.append(bb_insts)
  }
  insts
}

///|
pub fn from_gmir_module(mod : @GMIR.Module) -> Array[RvAsm] raise {
  let insts : Array[RvAsm] = Array::new()
  // collect all global functions
  mod.functions.filter(f => f.is_external).each(f => insts.push(Global(f.name)))
  mod.functions.each(func => {
    let func_insts = from_gmir_func(func)
    insts.append(func_insts)
  })

  // Modify main function's return to ecall
  // because some emulators can't handle normal ret in main
  modify_main_ret_to_ecall(insts)
  insts
}
