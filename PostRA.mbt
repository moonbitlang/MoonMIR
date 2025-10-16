///|
pub fn Function::post_ra(self : Function) -> Unit {
  // Step 1. Prologue/Epilogue Insertion
  // 1-1. Collect Callee-Saved Registers
  // 1-2. If callee-saved registers are used, save them in prologue
  //      and restore them in epilogue.
  // 1-3. Insert ra save/restore instructions. (if call instructions exist)
  // 1-4. Insert sp, fp modification instructions.
  self.prologue_epilogue_insertion()

  // Step 2. Adjust Stack Offsets, StackPtr and FramePtr
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
  for r in callee_saved_regs {
    let offset = -self.extend_reg_stack(8L, 8L)
    match r {
      IRegister(src) => {
        let inst = Instruction::new(
          IStore(64),
          [IRegister(src)],
          [Mem(FramePtr, offset)],
          entry_bb,
        )
        callee_saved_reg_locs.set(r, offset)
        entry_bb.insts.insert(0, inst)
      }
      FRegister(src) => {
        let inst = Instruction::new(
          FStore(64),
          [FRegister(src)],
          [Mem(FramePtr, offset)],
          entry_bb,
        )
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
    for r in callee_saved_regs {
      let offset = callee_saved_reg_locs.get(r).unwrap()
      match r {
        IRegister(dst) => {
          let inst = Instruction::new(
            ILoad(64),
            [Mem(FramePtr, offset)],
            [IRegister(dst)],
            term_bb,
          )
          term_bb.push_inst_before_terminator(inst)
        }
        FRegister(dst) => {
          let inst = Instruction::new(
            FLoad(64),
            [Mem(FramePtr, offset)],
            [FRegister(dst)],
            term_bb,
          )
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
  let need_save_ra = self.has_inst_with_opcode(Call)
  if need_save_ra {
    let offset = -self.extend_reg_stack(8L, 8L)
    let store_ra_inst = Instruction::new(
      IStore(64),
      [IRegister(ReturnAddr)],
      [Mem(FramePtr, offset)],
      entry_bb,
    )
    entry_bb.insts.insert(0, store_ra_inst)
    for term_bb in terminal_bbs {
      let load_ra_inst = Instruction::new(
        ILoad(64),
        [Mem(FramePtr, offset)],
        [IRegister(ReturnAddr)],
        term_bb,
      )
      term_bb.push_inst_before_terminator(load_ra_inst)
    }
  }
  if self.reg_stack_size > 0 {
    self.var_stack_size = (self.var_stack_size + 8 - 1) / 8 * 8 // align to 8 bytes
  }

  // Step 5. Calculate total stack size, insert sp, fp modification instructions
  let total_stack_size = self.var_stack_size + self.reg_stack_size
  let alloc_stack_inst = Instruction::new(
    IBinary(Add, 64),
    [IRegister(StackPtr)],
    [IRegister(StackPtr), Imm(-total_stack_size)],
    entry_bb,
  )
  let store_fp_inst = Instruction::new(
    IStore(64),
    [IRegister(FramePtr)],
    [Mem(StackPtr, self.var_stack_size)],
    entry_bb,
  )
  let set_fp_inst = Instruction::new(
    IBinary(Add, 64),
    [IRegister(FramePtr)],
    [IRegister(StackPtr), Imm(self.var_stack_size)],
    entry_bb,
  )
  entry_bb.insts.insert(0, set_fp_inst)
  entry_bb.insts.insert(0, store_fp_inst)
  entry_bb.insts.insert(0, alloc_stack_inst)
  for term_bb in terminal_bbs {
    let dealloc_stack_inst = Instruction::new(
      IBinary(Add, 64),
      [IRegister(StackPtr)],
      [IRegister(StackPtr), Imm(total_stack_size)],
      term_bb,
    )
    let load_fp_inst = Instruction::new(
      ILoad(64),
      [Mem(StackPtr, self.var_stack_size)],
      [IRegister(FramePtr)],
      term_bb,
    )
    term_bb.push_inst_before_terminator(dealloc_stack_inst)
    term_bb.push_inst_before_terminator(load_fp_inst)
  }
}

///|
pub fn Function::adjust_mem_operands(self : Function) -> Unit {
  let { var_stack_size, reg_stack_size, .. } = self
  let total_stack_size = var_stack_size + reg_stack_size
  for inst in self.inst_iter() {
    for i, def in inst.defs {
      match def {
        Mem(FramePtr, offset) =>
          inst.defs[i] = Mem(StackPtr, offset + total_stack_size)
        Mem(FramePtrPrim, offset) =>
          inst.defs[i] = Mem(StackPtr, offset + var_stack_size)
        _ => ()
      }
    }
    for i, use_ in inst.uses {
      match use_ {
        Mem(FramePtr, offset) =>
          inst.uses[i] = Mem(StackPtr, offset + total_stack_size)
        Mem(FramePtrPrim, offset) =>
          inst.uses[i] = Mem(StackPtr, offset + var_stack_size)
        _ => ()
      }
    }
  }
}
