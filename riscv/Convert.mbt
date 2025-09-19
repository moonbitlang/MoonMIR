///|
pub suberror GMIRToRvAsmError String derive(Show)

///|
pub fn Reg::from_vreg(v : Int) -> Reg raise {
  match v {
    0 => A0
    1 => A1
    2 => A2
    3 => A3
    4 => A4
    5 => A5
    6 => A6
    7 => A7
    8 => T0
    9 => T1
    10 => T2
    11 => T3
    12 => T4
    13 => T5
    14 => T6
    15 => S1
    16 => S2
    17 => S3
    18 => S4
    19 => S5
    20 => S6
    21 => S7
    22 => S8
    23 => S9
    24 => S10
    25 => S11
    _ => raise GMIRToRvAsmError("Unsupported vreg number: \{v}")
  }
}

///|
pub fn FReg::from_vfreg(v : Int) -> FReg raise {
  match v {
    0 => Fa0
    1 => Fa1
    2 => Fa2
    3 => Fa3
    4 => Fa4
    5 => Fa5
    6 => Fa6
    7 => Fa7
    8 => Ft0
    9 => Ft1
    10 => Ft2
    11 => Ft3
    12 => Ft4
    13 => Ft5
    14 => Ft6
    15 => Ft7
    16 => Fs0
    17 => Fs1
    18 => Fs2
    19 => Fs3
    20 => Fs4
    21 => Fs5
    22 => Fs6
    23 => Fs7
    24 => Fs8
    25 => Fs9
    26 => Fs10
    27 => Fs11
    _ => raise GMIRToRvAsmError("Unsupported vfreg number: \{v}")
  }
}

///|
pub fn from_gmir_inst(inst : @GMIR.Instruction) -> RvAsm raise {
  match inst {
    { opcode: Addq, defs: [Reg(dst)], uses: [Reg(src1), Reg(src2)] } => {
      let dst = Reg::from_vreg(dst)
      let src1 = Reg::from_vreg(src1)
      let src2 = Reg::from_vreg(src2)
      Add(dst, src1, src2)
    }
    { opcode: Subq, defs: [Reg(dst)], uses: [Reg(src1), Reg(src2)] } => {
      let dst = Reg::from_vreg(dst)
      let src1 = Reg::from_vreg(src1)
      let src2 = Reg::from_vreg(src2)
      Sub(dst, src1, src2)
    }
    { opcode: Movq, defs: [Reg(dst)], uses: [Imm(i)] } => {
      let dst = Reg::from_vreg(dst)
      Li(dst, i.to_string())
    }
    { opcode: Movq, defs: [Reg(dst)], uses: [Reg(src)] } => {
      let dst = Reg::from_vreg(dst)
      let src = Reg::from_vreg(src)
      Mv(dst, src)
    }
    { opcode: Ret, defs: [], uses: [] } => Ret
    { opcode: Addl, defs: [Reg(dst)], uses: [Reg(src1), Reg(src2)] } => {
      let dst = Reg::from_vreg(dst)
      let src1 = Reg::from_vreg(src1)
      let src2 = Reg::from_vreg(src2)
      Addw(dst, src1, src2)
    }
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
  bb.insts.each(inst => insts.push(from_gmir_inst(inst)))
  insts
}

///|
pub fn from_gmir_func(func : @GMIR.Function) -> Array[RvAsm] raise {
  let insts : Array[RvAsm] = Array::new()
  let fname = func.name
  insts.push(Label(fname))
  if func.stack_size > 0 {
    insts.push(Addi(Sp, Sp, -func.stack_size.to_int()))
  }
  for i, bb in func.body {
    let bb_insts = from_gmir_bb(bb, i)
    insts.append(bb_insts)
  }
  insts
}

///|
pub fn from_gmir_module(mod : @GMIR.Module) -> Array[RvAsm] raise {
  let insts : Array[RvAsm] = Array::new()
  mod.functions.each(func => {
    let func_insts = from_gmir_func(func)
    insts.append(func_insts)
  })

  // Modify main function's return to ecall
  // because some emulators can't handle normal ret in main
  modify_main_ret_to_ecall(insts)
  insts
}
