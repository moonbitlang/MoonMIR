///|
pub suberror GMIRToRvAsmError String derive(Show)

///|
pub fn Reg::from_mir_operand(v : @GMIR.Operand) -> Reg raise {
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
    _ => raise GMIRToRvAsmError("Error: Unsupported GMIR register: \{v}")
  }
}

///|
pub fn from_gmir_inst(inst : @GMIR.Instruction) -> RvAsm raise {
  match inst {
    { opcode: Addq, defs: [dst], uses: [src1, Imm(src2)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      Addi(dst, src1, src2.to_int())
    }
    { opcode: Addq, defs: [dst], uses: [src1, src2], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      let src2 = Reg::from_mir_operand(src2)
      Add(dst, src1, src2)
    }
    { opcode: Subq, defs: [dst], uses: [src1, Imm(src2)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      Addi(dst, src1, -src2.to_int())
    }
    { opcode: Subq, defs: [dst], uses: [src1, src2] , ..} => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      let src2 = Reg::from_mir_operand(src2)
      Sub(dst, src1, src2)
    }
    { opcode: Movq, defs: [dst], uses: [Imm(i)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      Li(dst, i.to_string())
    }
    { opcode: Movq, defs: [dst], uses: [src], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src = Reg::from_mir_operand(src)
      Mv(dst, src)
    }
    { opcode: Ret, defs: [], uses: [], .. } => Ret
    { opcode: Addl, defs: [dst], uses: [src1, Imm(src2)], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      Addi(dst, src1, src2.to_int())
    }
    { opcode: Addl, defs: [dst], uses: [src1, src2], .. } => {
      let dst = Reg::from_mir_operand(dst)
      let src1 = Reg::from_mir_operand(src1)
      let src2 = Reg::from_mir_operand(src2)
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
