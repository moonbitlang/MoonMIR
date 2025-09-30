
pub fn Module::translate_llvm_module(
  self: Self,
  llvm_mod: @IR.Module,
) -> Unit raise MIRError {
  self.clear()

  self.llvm_mod = Some(llvm_mod)

  // Step 1: Translate global values
  // Step 2: Translate functions
  for func_pair in llvm_mod.functions {
    let (_, func) = func_pair
    if func.isDeclaration() {
      self.external_functions.set(func.getName().unwrap(), func)
    } else {
      let fname = func.getName().unwrap()
      let f = self.add_function(fname, [])
      f.translate_llvm_function(func)
    }
  }
}

pub fn Function::translate_llvm_function(self: Self, llvm_func: @IR.Function) -> Unit raise MIRError {
  self.clear()
  self.llvm_func = Some(llvm_func)

  // Step 1: Translate parameters
  self.translate_params()

  // Step 2: Traverse llvm basic blocks in Reverse Post-Order
  let llvm_machine_bbs = self.traverse_llvm_basic_blocks()

  // Step 3: Traverse all llvm instructions (for binding values to registers)
  self.traverse_llvm_instructions(llvm_func)

  // Step 4: Translate each basic block
  for pair in llvm_machine_bbs {
    let (llvm_bb, machine_bb) = pair
    machine_bb.translate_llvm_basic_block(llvm_bb)
  }

  // Step 5: Phi Elimination
  self.phi_elimination()
}

///|
#callsite(autofill(loc))
pub fn Function::translate_params(self: Self, loc~: SourceLoc) -> Unit {
  guard self.llvm_func is Some(llvm_func) else {
    let msg = 
      $|Fatal Error happened in \{loc}
      #|LLVM function is not set for Function \{self.name}
    println(msg)
    panic()
  }
  let arg_patterns = llvm_func.arguments.map(
    arg => if arg.getType().isIEEELikeFPTy() { F } else { I }
  )
  self.set_params_by_patterns(arg_patterns)

  llvm_func.arguments.zip_to_iter2(self.params).each(
    (arg, param) => self.value_map.set(arg, param)
  )
}

#callsite(autofill(loc))
pub fn Function::traverse_llvm_basic_blocks(self: Self, loc~: SourceLoc) -> Array[(@IR.BasicBlock, BasicBlock)] {
  guard self.llvm_func is Some(llvm_func) else {
    let msg = 
      $|Fatal Error happened in \{loc}
      #|LLVM function is not set for Function \{self.name}
    println(msg)
    panic()
  }
  let sorted_bbs = sort_llvm_basick_block(llvm_func)
  let llvm_machine_bbs: Array[(@IR.BasicBlock, BasicBlock)] = Array::new()
  for llvm_bb in sorted_bbs {
    let label = match llvm_bb.getName() {
      Some(n) => n
      None => "\{self.name}_L\{self.bbmap.size()}"
    }
    let machine_bb = BasicBlock::new(self, label)
    self.body.push(machine_bb)
    self.value_map.set(llvm_bb, Label(label))
    self.bbmap.set(label, machine_bb)
    llvm_machine_bbs.push((llvm_bb, machine_bb))
  }
  llvm_machine_bbs
}

fn sort_llvm_basick_block(llvm_func: @IR.Function) -> Array[@IR.BasicBlock] {
  let basic_blocks : Array[@IR.BasicBlock] = Array::new()
  let entry_bb = llvm_func.getEntryBlock().unwrap()
  fn dfs(bb : @IR.BasicBlock, visited : Set[@IR.BasicBlock]) -> Unit {
    if visited.contains(bb) {
      return
    }
    visited.add(bb)
    for succ in bb.getSuccessors().rev_iter() {
      dfs(succ, visited)
    }
    basic_blocks.push(bb)
  }

  dfs(entry_bb, Set::new())
  basic_blocks.rev()
}

pub fn Function::traverse_llvm_instructions(self: Self, llvm_func: @IR.Function) -> Unit raise MIRError {
  let llvm_mod = llvm_func.getModule()
  let data_layout = llvm_mod.getDataLayout()
  for llvm_inst in llvm_func.instIter() {
    match llvm_inst.asInstEnum() {
      AllocaInst({ data_ty, align, ..}) => {
        let data_size = data_layout.getTypeAllocSize(data_ty).to_int64()
        let align = align.to_int64()
        let var_stack_loc = self.extend_var_stack(data_size, align)
        self.bind_llvm_value_to_mem(llvm_inst, FramePtrPrim, -var_stack_loc)
      }
      _ => {
        let llvm_ty = llvm_inst.getType()
        match llvm_ty.asTypeEnum() {
          Int1Type(_) | Int8Type(_) |
          Int16Type(_) | Int32Type(_) |
          Int64Type(_) | PointerType(_) => {
            let dst = self.new_virtual_reg()
            self.bind_llvm_value_to_register(llvm_inst, dst)
          }
          FloatType(_) | DoubleType(_) => {
            let dst = self.new_virtual_freg()
            self.bind_llvm_value_to_fregister(llvm_inst, dst)
          }
          VoidType(_) => ()
          _ => {
            raise IRTranslateError("Cannot bind LLVM instruction type \{llvm_ty} to a register")
          }
        }
      }
    }
  }
}

pub fn BasicBlock::translate_llvm_basic_block(
  self: Self, llvm_bb: @IR.BasicBlock
) -> Unit raise MIRError {
  self.clear()
  let func = self.parent
  let builder = IRBuilder::new(func, self)
  for inst in llvm_bb.instIter() {
    let insts = translate_llvm_inst(inst, builder)
    insts.each(i => self.push(i))
  }
}

pub fn translate_llvm_inst(
  llvm_inst: &@IR.Instruction,
  builder: IRBuilder
) -> Array[Instruction] raise MIRError {
  let func = builder.func
  let llvm_mod = llvm_inst.getModule()
  let data_layout = llvm_mod.getDataLayout()
  match llvm_inst.asInstEnum() {
    // AllocaInst has been handled in traverse_llvm_instructions
    AllocaInst(_) => []
    LoadInst(load_inst) => translate_llvm_load_inst(load_inst, builder, func, data_layout)
    StoreInst(store_inst) => translate_llvm_store_inst(store_inst, builder, func, data_layout)
    _ => raise IRTranslateError("Translation for LLVM instruction \{llvm_inst} is not implemented")
  }
}

pub fn translate_llvm_load_inst(llvm_inst: @IR.LoadInst, builder: IRBuilder, func: Function, data_layout: @IR.DataLayout) -> Array[Instruction] raise MIRError {
  let { vty, ptr, ..} = llvm_inst
  guard func.get_operand_from_llvm_value(ptr) is Some(ptr_op) else {
    raise IRTranslateError("LoadInst: pointer operand not found in value_map")
  }
  let (base, offset) = match ptr_op {
    Mem(base, offset) => (base, offset)
    IRegister(r) => (r, 0L)
    _ => raise IRTranslateError("LoadInst: pointer operand is not a memory address or integer register")
  }
  let data_size = data_layout.getTypeAllocSizeInBits(vty)
  guard func.get_operand_from_llvm_value(llvm_inst) is Some(dst_op) else {
    raise IRTranslateError("LoadInst: destination operand not found in value_map")
  }
  let minst = match dst_op {
    IRegister(dst) => builder.build_loadi(data_size, dst~, base~, offset~)
    FRegister(dst) => builder.build_loadf(data_size, dst~, base~, offset~)
    _ => raise IRTranslateError("LoadInst: destination operand is not an integer or floating-point register")
  }
  [minst]
}

pub fn translate_llvm_store_inst(llvm_inst: @IR.StoreInst, builder: IRBuilder, func: Function, data_layout: @IR.DataLayout) -> Array[Instruction] raise MIRError {
  let { value, ptr, ..} = llvm_inst
  guard func.get_operand_from_llvm_value(value) is Some(src_op) else {
    raise IRTranslateError("StoreInst: value operand not found in value_map")
  }
  guard func.get_operand_from_llvm_value(ptr) is Some(ptr_op) else {
    raise IRTranslateError("StoreInst: pointer operand not found in value_map")
  }
  let (base, offset) = match ptr_op {
    Mem(base, offset) => (base, offset)
    IRegister(r) => (r, 0L)
    _ => raise IRTranslateError("StoreInst: pointer operand is not a memory address or integer register")
  }
  let data_size = data_layout.getTypeAllocSizeInBits(value.getType())
  match src_op {
    IRegister(src) => [
      builder.build_storei(data_size, src~, base~, offset~)
    ]
    FRegister(src) => [
      builder.build_storef(data_size, src~, base~, offset~)
    ]
    Imm(src) => {
      let tmp = func.new_virtual_reg()
      [
        builder.build_imove_imm(data_size, dst=tmp, src~),
        builder.build_storei(data_size, src=tmp, base~, offset~)
      ]
    }
    FImm(src) => {
      let tmp = func.new_virtual_freg()
      [
        builder.build_fmove_imm(data_size, dst=tmp, src~),
        builder.build_storef(data_size, src=tmp, base~, offset~)
      ]
    }
    Mem(b, o) => {
      let tmp = func.new_virtual_reg()
      [
        builder.build_loadi(data_size, dst=tmp, base=b, offset=o),
        builder.build_storei(data_size, src=tmp, base~, offset~)
      ]
    }
    Label(label) => {
      let tmp = func.new_virtual_reg()
      [
        builder.build_load_addr(tmp, label),
        builder.build_storei(data_size, src=tmp, base~, offset~)
      ]
    }
  }
}

pub fn Function::phi_elimination(self: Self) -> Unit {
  ...
}

