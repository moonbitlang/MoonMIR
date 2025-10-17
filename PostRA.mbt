///|
pub fn Module::post_ra(self : Module) -> Unit {
  self.functions.values().each(f => f.post_ra())
}

///|
pub fn Function::post_ra(self : Function) -> Unit {
  // Step 1. Store and Load Caller-Saved Registers
  self.store_load_caller_saved_registers()

  // Step 2. Prologue/Epilogue Insertion
  // 1-1. Collect Callee-Saved Registers
  // 1-2. If callee-saved registers are used, save them in prologue
  //      and restore them in epilogue.
  // 1-3. Insert ra save/restore instructions. (if call instructions exist)
  // 1-4. Insert sp, fp modification instructions.
  self.prologue_epilogue_insertion()

  // Step 3. Adjust Stack Offsets, StackPtr and FramePtr
  // We now have three kinds of mem
  // 1. Mem(FromePtr, offset)
  // 2. Mem(StackPtr, offset)
  // 3. Mem(FramePtrPrim, offset)
  // FramePtr = StackPtr + var_stack_size + reg_stack_size
  // FromePtrPrim = StackPtr + var_stack_size
  // Hence:
  // Mem(FramePtr, offset) -> Mem(StackPtr, offset + var_stack_size + reg_stack_size)
  // Mem(FramePtrPrim, offset) -> Mem(StackPtr, offset + var_stack_size)
  self.adjust_mem_operands()
}

// For each call instruction, if it's live-out registers contain
// caller-saved registers, like a0, a1, ..., t0, t1, ..., fa0, ...
// store them in reg_stack before the call instruction
// and load them back after the call instruction.

///|
fn Function::store_load_caller_saved_registers(self : Self) -> Unit {
  fn is_caller_saved_register(op : Operand) -> Bool {
    match op {
      IRegister(AReg(_)) => true // Argument registers are caller-saved in RISC-V
      IRegister(TReg(_)) => true // Temporary registers are caller-saved
      FRegister(FAReg(_)) => true // Float argument registers are caller-saved
      FRegister(FTReg(_)) => true // Float temporary registers are caller-saved
      _ => false
    }
  }

  // Check if a register is used to return values from function calls
  fn is_return_register(op : Operand) -> Bool {
    match op {
      IRegister(AReg(0)) => true // a0 is the integer return register
      FRegister(FAReg(0)) => true // fa0 is the float return register
      _ => false
    }
  }

  let reg_stack_map : Map[Operand, Int64] = Map::new()
  let call_insts = self.collect_insts_with_opcode(Call)
  for inst in call_insts {
    for op in inst.live_out.iter().filter(is_caller_saved_register) {
      // Skip return registers - they should not be restored after the call
      // as they contain the return value
      if is_return_register(op) {
        continue
      }
      let { func, bb, .. } = inst
      let builder = IRBuilder::new(func, bb)
      if !reg_stack_map.contains(op) {
        let offset = -self.extend_reg_stack(8L, 8L)
        reg_stack_map.set(op, offset)
      }
      let offset = reg_stack_map.get(op).unwrap()
      // Store before call
      let store_inst = match op {
        IRegister(src) =>
          try! builder.build_storei(64, src~, base=FramePtr, offset~)
        FRegister(src) =>
          try! builder.build_storef(64, src~, base=FramePtr, offset~)
        _ => {
          println(
            "Compiler ICE: Unexpected register type in caller-saved registers",
          )
          panic()
        }
      }
      let _ = inst.bb.insert_inst_before(before=inst, store_inst)
      // Load after call
      let load_inst = match op {
        IRegister(dst) =>
          try! builder.build_loadi(64, dst~, base=FramePtr, offset~)
        FRegister(dst) =>
          try! builder.build_loadf(64, dst~, base=FramePtr, offset~)
        _ => {
          println(
            "Compiler ICE: Unexpected register type in caller-saved registers",
          )
          panic()
        }
      }
      let _ = inst.bb.insert_inst_after(after=inst, load_inst)

    }
  }
}

///|
fn Function::collect_callee_saved_registers(self : Function) -> Array[Operand] {
  let callee_saved_reg : Set[Operand] = Set::new()
  for inst in self.inst_iter() {
    for def in inst.defs {
      if def is (IRegister(SReg(_)) | FRegister(FSReg(_))) {
        callee_saved_reg.add(def)
      }
    }
    for use_ in inst.uses {
      if use_ is (IRegister(SReg(_)) | FRegister(FSReg(_))) {
        callee_saved_reg.add(use_)
      }
    }
  }
  callee_saved_reg.to_array()
}

///|
fn Function::prologue_epilogue_insertion(self : Function) -> Unit {
  // Step 1. Collect Callee-Saved Registers
  let callee_saved_regs = self.collect_callee_saved_registers()
  let callee_saved_reg_locs : Map[Operand, Int64] = Map::new()

  // Step 2. Insert Prologue Instructions
  let entry_bb = self.get_entry_block().unwrap()
  let builder = IRBuilder::new(self, entry_bb)
  for r in callee_saved_regs {
    let offset = -self.extend_reg_stack(8L, 8L)
    match r {
      IRegister(src) => {
        let inst = try! builder.build_storei(64, src~, base=FramePtr, offset~)
        callee_saved_reg_locs.set(r, offset)
        entry_bb.insts.insert(0, inst)
      }
      FRegister(src) => {
        let inst = try! builder.build_storef(64, src~, base=FramePtr, offset~)
        callee_saved_reg_locs.set(r, offset)
        entry_bb.insts.insert(0, inst)
      }
      _ => {
        println(
          "Compiler ICE: Unexpected register type in callee-saved registers",
        )
        panic()
      }
    }
  }

  // Step 3. Insert Epilogue Instructions
  let terminal_bbs = self.terminal_blocks
  for term_bb in terminal_bbs {
    let builder = IRBuilder::new(self, term_bb)
    for r in callee_saved_regs {
      let offset = callee_saved_reg_locs.get(r).unwrap()
      match r {
        IRegister(dst) => {
          let inst = try! builder.build_loadi(64, dst~, base=FramePtr, offset~)
          term_bb.push_inst_before_terminator(inst)
        }
        FRegister(dst) => {
          let inst = try! builder.build_loadf(64, dst~, base=FramePtr, offset~)
          term_bb.push_inst_before_terminator(inst)
        }
        _ => {
          println(
            "Compiler ICE: Unexpected register type in callee-saved registers",
          )
          panic()
        }
      }
    }
  }

  // Step 4. Insert ra save/restore instructions if needed.
  let builder = IRBuilder::new(self, entry_bb)
  let need_save_ra = self.has_inst_with_opcode(Call)
  if need_save_ra {
    let offset = -self.extend_reg_stack(8L, 8L)
    let store_ra_inst = try! builder.build_storei(
        64,
        src=ReturnAddr,
        base=FramePtr,
        offset~,
      )
    entry_bb.insts.insert(0, store_ra_inst)
    for term_bb in terminal_bbs {
      let builder = IRBuilder::new(self, term_bb)
      let load_ra_inst = try! builder.build_loadi(
          64,
          dst=ReturnAddr,
          base=FramePtr,
          offset~,
        )
      term_bb.push_inst_before_terminator(load_ra_inst)
    }
  }
  if self.reg_stack_size > 0 {
    self.var_stack_size = (self.var_stack_size + 8 - 1) / 8 * 8 // align to 8 bytes
  }

  // Step 5. Calculate total stack size, insert sp, fp modification instructions
  if self.var_stack_size == 0 && self.reg_stack_size == 0 {
    return
  }
  // need space for fp
  let offset = -self.extend_reg_stack(8L, 8L)
  let total_stack_size = self.var_stack_size + self.reg_stack_size
  let builder = IRBuilder::new(self, entry_bb)
  let alloc_stack_inst = try! builder.build_ibinary_imm(
      Add,
      64,
      dst=StackPtr,
      src1=StackPtr,
      src2=-total_stack_size,
    )
  let store_fp_inst = try! builder.build_storei(
      64,
      src=FramePtr,
      base=FramePtr,
      offset~,
    )
  let set_fp_inst = try! builder.build_ibinary_imm(
      Add,
      64,
      dst=FramePtr,
      src1=StackPtr,
      src2=total_stack_size,
    )
  entry_bb.insts.insert(0, set_fp_inst)
  entry_bb.insts.insert(0, store_fp_inst)
  entry_bb.insts.insert(0, alloc_stack_inst)
  for term_bb in terminal_bbs {
    let builder = IRBuilder::new(self, term_bb)
    let load_fp_inst = try! builder.build_loadi(
        64,
        dst=FramePtr,
        base=StackPtr,
        offset=self.var_stack_size,
      )
    let dealloc_stack_inst = try! builder.build_ibinary_imm(
        Add,
        64,
        dst=StackPtr,
        src1=StackPtr,
        src2=total_stack_size,
      )
    term_bb.push_inst_before_terminator(load_fp_inst)
    term_bb.push_inst_before_terminator(dealloc_stack_inst)
  }
}

///|
pub fn Function::adjust_mem_operands(self : Function) -> Unit {
  let { var_stack_size, reg_stack_size, .. } = self
  let total_stack_size = var_stack_size + reg_stack_size
  for inst in self.inst_iter() {
    if inst
      is {
        opcode: IBinary(Add, _),
        uses: [IRegister(FramePtrPrim), Imm(i)],
        ..,
      } {
      inst.uses[0] = IRegister(StackPtr)
      inst.uses[1] = Imm(i + var_stack_size)
    }
    for i, def in inst.defs {
      match def {
        Mem(FramePtr, offset) =>
          // Local variables and saved registers, negative offset from fp
          inst.defs[i] = Mem(StackPtr, offset + total_stack_size)
        Mem(FramePtrPrim, offset) =>
          inst.defs[i] = Mem(StackPtr, offset + var_stack_size)
        _ => ()
      }
    }
    for i, use_ in inst.uses {
      match use_ {
        Mem(FramePtr, offset) =>
          // Local variables and saved registers, negative offset from fp
          inst.uses[i] = Mem(StackPtr, offset + total_stack_size)
        Mem(FramePtrPrim, offset) =>
          inst.uses[i] = Mem(StackPtr, offset + var_stack_size)
        _ => ()
      }
    }
    inst.live_in.remove(IRegister(FramePtrPrim))
    inst.live_out.remove(IRegister(FramePtrPrim))
  }
}
