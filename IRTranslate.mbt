///|
pub fn Module::translate_llvm_module(
  self : Self,
  llvm_mod : @IR.Module,
) -> Unit raise MIRError {
  self.llvm_mod = Some(llvm_mod)

  // Step 1: Translate global values
  self.translate_global_values(llvm_mod)

  // Step 2: Translate functions
  for func_pair in llvm_mod.functions {
    let (_, func) = func_pair
    if func.isDeclaration() {
      self.external_functions.set(func.getName().unwrap(), func)
    } else {
      let fname = func.getName().unwrap()
      let is_external = func.linkage.val is External
      let f = self.add_function(fname, [], is_external)
      f.translate_llvm_function(func)
    }
  }
}

///|
pub fn Module::translate_global_values(
  self : Self,
  llvm_mod : @IR.Module,
) -> Unit raise MIRError {
  let data_layout = llvm_mod.getDataLayout()
  for global_name, gv in llvm_mod.globals {
    match gv.asGlobalValueEnum() {
      Function(_) => ()
      GlobalVariable({ initializer: None, initializerTy, .. }) => {
        let size = data_layout
          .getTypeAllocSize(initializerTy)
          .reinterpret_as_uint()
        let _ = self.add_global_zero_data(global_name, size)

      }
      GlobalVariable({ initializer: Some(initializer), .. }) =>
        self.translate_llvm_global_constant(global_name, initializer)
      GlobalConstant({ value, .. }) =>
        self.translate_llvm_global_constant(global_name, value)
    }
  }
}

///|
pub fn Module::translate_llvm_global_constant(
  self : Self,
  global_name : String,
  global_constant : &@IR.Constant,
) -> Unit raise MIRError {
  let gv = match global_constant.asConstantEnum() {
    ConstantInt({ vty, value, .. }) =>
      match vty.asIntegerTypeEnum() {
        Int1Type(_) => {
          let data = [Byte(value.to_byte())]
          self.add_global_data(global_name, data)
        }
        Int8Type(_) => {
          let data = [Byte(value.to_byte())]
          self.add_global_data(global_name, data)
        }
        Int16Type(_) => {
          let data = [Half(value.to_uint16())]
          self.add_global_data(global_name, data)
        }
        Int32Type(_) => {
          let data = [Word(value.to_int().reinterpret_as_uint())]
          self.add_global_data(global_name, data)
        }
        Int64Type(_) => {
          let data = [Quad(value.reinterpret_as_uint64())]
          self.add_global_data(global_name, data)
        }
      }
    ConstantFP({ vty, value, .. }) =>
      match vty.asFPTypeEnum() {
        FloatType(_) => {
          let bits = value.to_float().reinterpret_as_uint()
          let data = [Word(bits)]
          self.add_global_data(global_name, data)
        }
        DoubleType(_) => {
          let bits = value.reinterpret_as_uint64()
          let data = [Quad(bits)]
          self.add_global_data(global_name, data)
        }
        ty =>
          raise IRTranslateError(
            "Unsupported floating point type \{ty} in global constant.",
          )
      }
    ConstantPointerNull(_) => {
      let data = [Quad(0)]
      self.add_global_data(global_name, data)
    }
    ConstantString({ data, .. }) =>
      self.add_global_string(label=global_name, content=data)
    ConstantArray(_) =>
      raise IRTranslateError(
        "ConstantArray in global constant is not supported yet.",
      )
    ConstantStruct(_) =>
      raise IRTranslateError(
        "ConstantStruct in global constant is not supported yet.",
      )
    _ => raise IRTranslateError("Unsupported constant type in global constant.")
  }
  let _ = gv

}

///|
pub fn Function::translate_llvm_function(
  self : Self,
  llvm_func : @IR.Function,
) -> Unit raise MIRError {
  self.llvm_func = Some(llvm_func)

  // Step 1: Traverse llvm basic blocks in Reverse Post-Order
  let llvm_machine_bbs = self.traverse_llvm_basic_blocks()

  // Step 2: Translate parameters
  self.translate_params()

  // Step 3: Traverse all llvm instructions (for binding values to registers)
  self.traverse_llvm_instructions(llvm_func)

  // Step 4: Translate each basic block
  for pair in llvm_machine_bbs {
    let (llvm_bb, machine_bb) = pair
    machine_bb.translate_llvm_basic_block(llvm_bb)
  }
  if self.terminal_blocks.is_empty() {
    self.terminal_blocks.push(self.body.last().unwrap())
  }

  // Step 5: Phi Elimination
  self.phi_elimination()
}

///|
#callsite(autofill(loc))
pub fn Function::translate_params(self : Self, loc~ : SourceLoc) -> Unit {
  guard self.llvm_func is Some(llvm_func) else {
    let msg =
      $|Fatal Error happened in \{loc}
      #|LLVM function is not set for Function \{self.name}
    println(msg)
    panic()
  }
  fn pattern_of_llvm_arg(arg : @IR.Argument) {
    match arg.getType().isIEEELikeFPTy() {
      true => F
      false => I
    }
  }

  let arg_patterns = llvm_func.arguments.map(pattern_of_llvm_arg)
  self.set_params_by_patterns(arg_patterns)
  let entry_bb = self.get_entry_block().unwrap()
  let buiilder = IRBuilder::new(self, entry_bb)
  for arg, param in llvm_func.arguments.zip_to_iter2(self.params) {
    let data_size = 64 // Riscv64
    if param is IRegister(r) {
      let tmp = self.new_virtual_reg()
      let move_inst = buiilder.build_imove(data_size, dst=tmp, src=r) catch {
        _ => abort("")
      }
      entry_bb.push(move_inst)
      self.value_map.set(arg, IRegister(tmp))
      continue
    }
    if param is FRegister(r) {
      let tmp = self.new_virtual_freg()
      let move_inst = buiilder.build_fmove(data_size, dst=tmp, src=r) catch {
        _ => abort("")
      }
      entry_bb.push(move_inst)
      self.value_map.set(arg, FRegister(tmp))
      continue
    }
    let is_fp = arg.getType().isIEEELikeFPTy()
    guard param is Mem(base, offset)
    if is_fp {
      let tmp = self.new_virtual_freg()
      let load_inst = buiilder.build_loadf(data_size, dst=tmp, base~, offset~) catch {
        _ => abort("")
      }
      entry_bb.push(load_inst)
      self.value_map.set(arg, FRegister(tmp))
    } else {
      let tmp = self.new_virtual_reg()
      let load_inst = buiilder.build_loadi(data_size, dst=tmp, base~, offset~) catch {
        _ => abort("")
      }
      entry_bb.push(load_inst)
      self.value_map.set(arg, IRegister(tmp))
    }
  }
}

///|
#callsite(autofill(loc))
pub fn Function::traverse_llvm_basic_blocks(
  self : Self,
  loc~ : SourceLoc,
) -> Array[(@IR.BasicBlock, BasicBlock)] {
  guard self.llvm_func is Some(llvm_func) else {
    let msg =
      $|Fatal Error happened in \{loc}
      #|LLVM function is not set for Function \{self.name}
    println(msg)
    panic()
  }
  let sorted_bbs = sort_llvm_basick_block(llvm_func)
  let llvm_machine_bbs : Array[(@IR.BasicBlock, BasicBlock)] = Array::new()
  for llvm_bb in sorted_bbs {
    let label = match llvm_bb.getName() {
      Some(n) => n
      None => "\{self.name}_L\{self.bbmap.length()}"
    }
    let machine_bb = BasicBlock::new(self, label)
    self.body.push(machine_bb)
    self.value_map.set(llvm_bb, Label(label))
    self.bbmap.set(label, machine_bb)
    llvm_machine_bbs.push((llvm_bb, machine_bb))
  }
  llvm_machine_bbs
}

///|
fn sort_llvm_basick_block(llvm_func : @IR.Function) -> Array[@IR.BasicBlock] {
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

///|
fn Function::traverse_llvm_instructions(
  self : Self,
  llvm_func : @IR.Function,
) -> Unit raise MIRError {
  let llvm_mod = llvm_func.getModule()
  let data_layout = llvm_mod.getDataLayout()
  for llvm_inst in llvm_func.instIter() {
    match llvm_inst.asInstEnum() {
      AllocaInst({ data_ty, align, .. }) => {
        let data_size = data_layout.getTypeAllocSize(data_ty).to_int64()
        let align = align.to_int64()
        let var_stack_loc = self.extend_var_stack(data_size, align)
        self.bind_llvm_value_to_mem(llvm_inst, FramePtrPrim, -var_stack_loc)
      }
      _ => {
        let llvm_ty = llvm_inst.getType()
        match llvm_ty.asTypeEnum() {
          Int1Type(_)
          | Int8Type(_)
          | Int16Type(_)
          | Int32Type(_)
          | Int64Type(_)
          | PointerType(_) => {
            let dst = self.new_virtual_reg()
            self.bind_llvm_value_to_register(llvm_inst, dst)
          }
          FloatType(_) | DoubleType(_) => {
            let dst = self.new_virtual_freg()
            self.bind_llvm_value_to_fregister(llvm_inst, dst)
          }
          VoidType(_) => ()
          _ =>
            raise IRTranslateError(
              "Cannot bind LLVM instruction type \{llvm_ty} to a register",
            )
        }
      }
    }
  }
}

///|
pub fn BasicBlock::translate_llvm_basic_block(
  self : Self,
  llvm_bb : @IR.BasicBlock,
) -> Unit raise MIRError {
  let func = self.parent
  let builder = IRBuilder::new(func, self)
  for inst in llvm_bb.instIter() {
    let insts = translate_llvm_inst(inst, builder)
    insts.each(i => self.push(i))
  }
}

///|
pub fn translate_llvm_inst(
  llvm_inst : &@IR.Instruction,
  builder : IRBuilder,
) -> Array[Instruction] raise MIRError {
  let func = builder.func
  let llvm_mod = llvm_inst.getModule()
  let data_layout = llvm_mod.getDataLayout()
  match llvm_inst.asInstEnum() {
    // AllocaInst has been handled in traverse_llvm_instructions
    AllocaInst(_) => []
    LoadInst(load_inst) =>
      translate_llvm_load_inst(load_inst, builder, func, data_layout)
    StoreInst(store_inst) =>
      translate_llvm_store_inst(store_inst, builder, func, data_layout)
    FNegInst(fneg_inst) =>
      translate_llvm_fneg_inst(fneg_inst, builder, func, data_layout)
    BinaryInst(binary_inst) =>
      translate_llvm_binary_inst(binary_inst, builder, func, data_layout)
    ICmpInst(icmp_inst) =>
      translate_llvm_icmp_inst(icmp_inst, builder, func, data_layout)
    FCmpInst(fcmp_inst) =>
      translate_llvm_fcmp_inst(fcmp_inst, builder, func, data_layout)
    BranchInst(branch_inst) =>
      translate_llvm_branch_inst(branch_inst, builder, func, data_layout)
    SwitchInst(switch_inst) =>
      translate_llvm_switch_inst(switch_inst, builder, func, data_layout)
    CastInst(cast_inst) =>
      translate_llvm_cast_inst(cast_inst, builder, func, data_layout)
    GetElementPtrInst(gep_inst) =>
      translate_llvm_gep_inst(gep_inst, builder, func, data_layout)
    SelectInst(select_inst) =>
      translate_llvm_select_inst(select_inst, builder, func, data_layout)
    ReturnInst(ret_inst) => translate_llvm_return_inst(ret_inst, builder, func)
    CallInst(call_inst) => translate_llvm_call_inst(call_inst, builder, func)
    PHINode(phi_node) => translate_llvm_phi_node(phi_node, func)
    ExtractValueInst(_) =>
      raise IRTranslateError(
        "Translation for LLVM instruction \{llvm_inst} is not implemented",
      )
    InsertValueInst(_) =>
      raise IRTranslateError(
        "Translation for LLVM instruction \{llvm_inst} is not implemented",
      )
  }
}

///|
///
/// IRTranslate from LLVM IR to MoonMIR for LoadInst.
///
/// ```mbt
/// let code =
///   #|fn demo() -> Int {
///   #|  let mut a = 10  // a is in memory
///   #|  return a
///   #|}
/// let llvm_mod = @TinyMoonBit.compile(code)
/// let rv64 = ArchConfig::riscv64()
/// // IRTranslate
/// let mir_mod = Module::new(rv64)
/// mir_mod.translate_llvm_module(llvm_mod)
/// let mir_func = mir_mod.get_function("demo").unwrap()
///
/// let expected =
///   #|func demo() {
///   #|entry:
///   #|  v1 = move.i32 10
///   #|  store.i32 (fp' - 4), v1
///   #|  v0 = load.i32 (fp' - 4)
///   #|  a0 = move.i64 v0
///   #|  ret
///   #|}
///   #|
///
/// inspect(mir_func, content=expected)
/// ```
pub fn translate_llvm_load_inst(
  llvm_inst : @IR.LoadInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  let { vty, ptr, .. } = llvm_inst
  guard func.get_operand_from_llvm_value(ptr) is Some(ptr_op) else {
    raise IRTranslateError("LoadInst: pointer operand not found in value_map")
  }
  let (base, offset) = match ptr_op {
    Mem(base, offset) => (base, offset)
    IRegister(r) => (r, 0L)
    _ =>
      raise IRTranslateError(
        "LoadInst: pointer operand is not a memory address or integer register",
      )
  }
  let data_size = data_layout.getTypeAllocSizeInBits(vty)
  guard func.get_operand_from_llvm_value(llvm_inst) is Some(dst_op) else {
    raise IRTranslateError(
      "LoadInst: destination operand not found in value_map",
    )
  }
  let minst = match dst_op {
    IRegister(dst) => builder.build_loadi(data_size, dst~, base~, offset~)
    FRegister(dst) => builder.build_loadf(data_size, dst~, base~, offset~)
    dst_op =>
      raise IRTranslateError(
        "LoadInst: destination operand is not an integer or floating-point register: \{dst_op}",
      )
  }
  [minst]
}

///|
///
/// IRTranslate from LLVM IR to MoonMIR for StoreInst.
///
/// ```mbt
/// let code =
///   #|fn demo() -> Int {
///   #|  let mut a = 10  // a is in memory
///   #|  return a
///   #|}
/// let llvm_mod = @TinyMoonBit.compile(code)
/// let rv64 = ArchConfig::riscv64()
/// // IRTranslate
/// let mir_mod = Module::new(rv64)
/// mir_mod.translate_llvm_module(llvm_mod)
/// let mir_func = mir_mod.get_function("demo").unwrap()
///
/// let expected =
///   #|func demo() {
///   #|entry:
///   #|  v1 = move.i32 10
///   #|  store.i32 (fp' - 4), v1
///   #|  v0 = load.i32 (fp' - 4)
///   #|  a0 = move.i64 v0
///   #|  ret
///   #|}
///   #|
///
/// inspect(mir_func, content=expected)
/// ```
pub fn translate_llvm_store_inst(
  llvm_inst : @IR.StoreInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  let { value, ptr, .. } = llvm_inst
  guard func.get_operand_from_llvm_value(value) is Some(src_op) else {
    raise IRTranslateError("StoreInst: value operand not found in value_map")
  }
  guard func.get_operand_from_llvm_value(ptr) is Some(ptr_op) else {
    raise IRTranslateError("StoreInst: pointer operand not found in value_map")
  }
  let (base, offset) = match ptr_op {
    Mem(base, offset) => (base, offset)
    IRegister(r) => (r, 0L)
    _ =>
      raise IRTranslateError(
        "StoreInst: pointer operand is not a memory address or integer register",
      )
  }
  let data_size = data_layout.getTypeAllocSizeInBits(value.getType())
  match src_op {
    IRegister(src) => [builder.build_storei(data_size, src~, base~, offset~)]
    FRegister(src) => [builder.build_storef(data_size, src~, base~, offset~)]
    Imm(src) => {
      let tmp = func.new_virtual_reg()
      [
        builder.build_imove_imm(data_size, dst=tmp, src~),
        builder.build_storei(data_size, src=tmp, base~, offset~),
      ]
    }
    FImm(src) => {
      let tmp = func.new_virtual_freg()
      [
        builder.build_fmove_imm(data_size, dst=tmp, src~),
        builder.build_storef(data_size, src=tmp, base~, offset~),
      ]
    }
    Label(label) => {
      let tmp = func.new_virtual_reg()
      [
        builder.build_load_addr(tmp, label),
        builder.build_storei(data_size, src=tmp, base~, offset~),
      ]
    }
    src_op =>
      raise IRTranslateError(
        "StoreInst: value operand is not a register, immediate, or label: \{src_op}",
      )
  }
}

///|
///
/// IRTranslate from LLVM IR to MoonMIR for Int or Float binary instructions.
///
/// ```mbt
/// let code =
///   #|fn add(x: Int, y: Int, fx: Double, fy: Double) -> Unit {
///   #|  let a = x + y 
///   #|  let fa = fx + fy
///   #|  return
///   #|}
///
/// let llvm_mod = @TinyMoonBit.compile(code)
/// let rv64_config = ArchConfig::riscv64()
/// let mir_mod = Module::new(rv64_config)
/// mir_mod.translate_llvm_module(llvm_mod)
/// let actual = mir_mod.get_function("add").unwrap()
///
/// let expected =
///   #|func add(a0, a1, fa0, fa1) {
///   #|entry:
///   #|  v0 = move.i64 a0
///   #|  v1 = move.i64 a1
///   #|  vf0 = move.f64 fa0
///   #|  vf1 = move.f64 fa1
///   #|  v2 = add.i32 v0, v1
///   #|  vf2 = fadd.f64 vf0, vf1
///   #|  ret
///   #|}
///   #|
/// inspect(actual, content = expected)
/// ```
pub fn translate_llvm_binary_inst(
  llvm_inst : @IR.BinaryInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  if llvm_inst.getType().isIEEELikeFPTy() {
    translate_llvm_float_binary_inst(llvm_inst, builder, func, data_layout)
  } else {
    translate_llvm_int_binary_inst(llvm_inst, builder, func, data_layout)
  }
}

///|
///
/// IRTranslate from LLVM IR to MIR for floating-point BinaryInst
///
/// ```mbt
/// let code =
///   #|fn add(x: Float, y: Float) -> Float {
///   #|  x + y
///   #|}
///
/// let llvm_mod = @TinyMoonBit.compile(code)
/// let rv64_config = ArchConfig::riscv64()
/// let mir_mod = Module::new(rv64_config)
/// mir_mod.translate_llvm_module(llvm_mod)
/// let actual = mir_mod.get_function("add").unwrap()
///
/// let expected =
///   #|func add(fa0, fa1) {
///   #|entry:
///   #|  vf0 = move.f64 fa0
///   #|  vf1 = move.f64 fa1
///   #|  vf2 = fadd.f32 vf0, vf1
///   #|  fa0 = move.f64 vf2
///   #|  ret
///   #|}
///   #|
/// inspect(actual, content = expected)
/// ```
pub fn translate_llvm_float_binary_inst(
  llvm_inst : @IR.BinaryInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  let { opcode, lhs, rhs, .. } = llvm_inst
  let data_size = data_layout.getTypeAllocSizeInBits(llvm_inst.getType())
  let binop = match opcode {
    FAdd => FAdd
    FSub => FSub
    FMul => FMul
    FDiv => FDiv
    FRem => FRem
    _ => raise IRTranslateError("Unsupported floating-point binary opcode")
  }
  guard func.get_operand_from_llvm_value(lhs) is Some(lhs_op) else {
    raise IRTranslateError("BinaryInst: lhs operand not found in value_map")
  }
  guard func.get_operand_from_llvm_value(rhs) is Some(rhs_op) else {
    raise IRTranslateError("BinaryInst: rhs operand not found in value_map")
  }
  guard func.get_operand_from_llvm_value(llvm_inst) is Some(dst_op) else {
    raise IRTranslateError(
      "BinaryInst: destination operand not found in value_map: \{llvm_inst}",
    )
  }
  guard dst_op is FRegister(dst) else {
    raise IRTranslateError(
      "BinaryInst: destination operand is not a floating-point register",
    )
  }
  match (lhs_op, rhs_op) {
    (FRegister(src1), FRegister(src2)) =>
      [builder.build_fbinary(binop, data_size, dst~, src1~, src2~)]
    (FRegister(src1), FImm(f)) => {
      let ireg = func.new_virtual_reg()
      let src2 = func.new_virtual_freg()
      [
        match data_size {
          32 =>
            builder.build_imove_imm(
              data_size,
              dst=ireg,
              src=f.to_float().reinterpret_as_int().to_int64(),
            )
          _ =>
            builder.build_imove_imm(
              data_size,
              dst=ireg,
              src=f.reinterpret_as_int64(),
            )
        },
        builder.build_fmove_from_ireg(data_size, dst=src2, src=ireg),
        builder.build_fbinary(binop, data_size, dst~, src1~, src2~),
      ]
    }
    (FImm(f), FRegister(src2)) => {
      let src1 = func.new_virtual_freg()
      let ireg = func.new_virtual_reg()
      let move_imm = match data_size {
        32 =>
          builder.build_imove_imm(
            data_size,
            dst=ireg,
            src=f.to_float().reinterpret_as_int().to_int64(),
          )
        _ =>
          builder.build_imove_imm(
            data_size,
            dst=ireg,
            src=f.reinterpret_as_int64(),
          )
      }
      [
        move_imm,
        builder.build_fmove_from_ireg(data_size, dst=src1, src=ireg),
        builder.build_fbinary(binop, data_size, dst~, src1~, src2~),
      ]
    }
    (FImm(f1), FImm(f2)) => {
      let f = match binop {
        FAdd => f1 + f2
        FSub => f1 - f2
        FMul => f1 * f2
        FDiv => f1 / f2
        FRem => f1 % f2
      }
      let ireg = func.new_virtual_reg()
      let move_imm = match data_size {
        32 =>
          builder.build_imove_imm(
            data_size,
            dst=ireg,
            src=f.to_float().reinterpret_as_int().to_int64(),
          )
        _ =>
          builder.build_imove_imm(
            data_size,
            dst=ireg,
            src=f.reinterpret_as_int64(),
          )
      }
      [move_imm, builder.build_fmove_from_ireg(data_size, dst~, src=ireg)]
    }
    (lhs_op, rhs_op) =>
      raise IRTranslateError(
        "Unsupported operand types for float binary operation, \{lhs_op}, \{rhs_op}",
      )
  }
}

///|
///
/// IRTranslate from LLVM IR to MIR for Int BinaryInst
///
/// ```mbt
/// let code = 
///   #|fn add(x: Int, y: Int) -> Int {
///   #|  x + y
///   #|}
///
/// let llvm_mod = @TinyMoonBit.compile(code)
/// let rv64_config = ArchConfig::riscv64()
/// let mir_mod = Module::new(rv64_config)
/// mir_mod.translate_llvm_module(llvm_mod)
/// let actual = mir_mod.get_function("add").unwrap()
///
/// let expected = 
///   #|func add(a0, a1) {
///   #|entry:
///   #|  v0 = move.i64 a0
///   #|  v1 = move.i64 a1
///   #|  v2 = add.i32 v0, v1
///   #|  a0 = move.i64 v2
///   #|  ret
///   #|}
///   #|
/// inspect(actual, content = expected)
/// ```
pub fn translate_llvm_int_binary_inst(
  llvm_inst : @IR.BinaryInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  let { opcode, lhs, rhs, .. } = llvm_inst
  let data_size = data_layout.getTypeAllocSizeInBits(llvm_inst.getType())
  let binop = match opcode {
    Add => Add
    Sub => Sub
    Mul => Mul
    UDiv | SDiv => Div
    URem | SRem => Rem
    And => And
    Or => Or
    Xor => Xor
    Shl => Shl
    LShr => LShr
    AShr => AShr
    _ => raise IRTranslateError("Unsupported integer binary opcode")
  }
  guard func.get_operand_from_llvm_value(lhs) is Some(lhs_op) else {
    raise IRTranslateError("BinaryInst: lhs operand not found in value_map")
  }
  guard func.get_operand_from_llvm_value(rhs) is Some(rhs_op) else {
    raise IRTranslateError("BinaryInst: rhs operand not found in value_map")
  }
  guard func.get_operand_from_llvm_value(llvm_inst) is Some(dst_op) else {
    raise IRTranslateError(
      "BinaryInst: destination operand not found in value_map, \{llvm_inst}",
    )
  }
  guard dst_op is IRegister(dst) else {
    raise IRTranslateError(
      "BinaryInst: destination operand is not an integer register",
    )
  }
  match (lhs_op, rhs_op) {
    (IRegister(src1), IRegister(src2)) =>
      [builder.build_ibinary(binop, data_size, dst~, src1~, src2~)]
    (IRegister(src1), Imm(src2)) =>
      [builder.build_ibinary_imm(binop, data_size, dst~, src1~, src2~)]
    (Imm(src1), IRegister(src2)) if binop.is_commutative() =>
      [builder.build_ibinary_imm(binop, data_size, dst~, src1=src2, src2=src1)] // swap
    (Imm(src1_imm), IRegister(src2)) => {
      let src1 = func.new_virtual_reg()
      [
        builder.build_imove_imm(data_size, dst=src1, src=src1_imm),
        builder.build_ibinary(binop, data_size, dst~, src1~, src2~),
      ]
    }
    (Imm(src1), Imm(src2)) => {
      let src = match binop {
        Add => src1 + src2
        Sub => src1 - src2
        Mul => src1 * src2
        Div => src1 / src2
        Rem => src1 % src2
        And => src1 & src2
        Or => src1 | src2
        Xor => src1 ^ src2
        Shl => src1 << src2.to_int()
        LShr =>
          (src1.reinterpret_as_uint64() >> src2.to_int()).reinterpret_as_int64()
        AShr => src1 >> src2.to_int()
      }
      [builder.build_imove_imm(data_size, dst~, src~)]
    }
    (lhs_op, rhs_op) =>
      raise IRTranslateError(
        "Unsupported operand types for integer binary operation: \{lhs_op}, \{rhs_op}",
      )
  }
}

///|
///
/// IRTranslate from LLVM IR to MoonMIR for FNegInst
///
/// ```mbt
/// let code =
///   #|fn neg(x: Float) -> Float {
///   #|  -x
///   #|}
///
/// let llvm_mod = @TinyMoonBit.compile(code)
/// let rv64_config = ArchConfig::riscv64()
/// let mir_mod = Module::new(rv64_config)
///
/// mir_mod.translate_llvm_module(llvm_mod)
/// let actual = mir_mod.get_function("neg").unwrap()
///
/// let expected =
///  #|func neg(fa0) {
///  #|entry:
///  #|  vf0 = move.f64 fa0
///  #|  vf1 = fneg.f32 vf0
///  #|  fa0 = move.f64 vf1
///  #|  ret
///  #|}
///  #|
///
/// inspect(actual, content = expected)
/// ```
pub fn translate_llvm_fneg_inst(
  llvm_inst : @IR.FNegInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  let { operand, .. } = llvm_inst
  guard func.get_operand_from_llvm_value(operand) is Some(src_op) else {
    raise IRTranslateError("FNegInst: operand not found in value_map")
  }
  guard func.get_operand_from_llvm_value(llvm_inst) is Some(dst_op) else {
    raise IRTranslateError(
      "FNegInst: destination operand not found in value_map",
    )
  }
  guard dst_op is FRegister(dst) else {
    raise IRTranslateError(
      "FNegInst: destination operand is not a floating-point register",
    )
  }
  let data_size = data_layout.getTypeAllocSizeInBits(llvm_inst.getType())
  match src_op {
    FRegister(src) => [builder.build_fneg(data_size, dst~, src~)]
    FImm(f) => {
      let ireg = func.new_virtual_reg()
      let src = func.new_virtual_freg()
      [
        builder.build_imove_imm(
          data_size,
          dst=ireg,
          src=f.reinterpret_as_int64(),
        ),
        builder.build_fmove_from_ireg(data_size, dst=src, src=ireg),
        builder.build_fneg(data_size, dst~, src~),
      ]
    }
    src_op =>
      raise IRTranslateError(
        "FNegInst: operand is not a memory address, floating-point register, or immediate value: \{src_op}",
      )
  }
}

///|
///
/// IRTranslate from LLVM IR to MoonMIR for ICmpInst.
///
/// ```mbt
/// let code = 
///   #|fn demo(a: Int, b: Int) -> Unit {
///   #|  let c = a < b
///   #|  let d = a <= b
///   #|  let e = a > b
///   #|  let f = a >= b
///   #|  let g = a == b
///   #|  let h = a != b
///   #|  return
///   #|}
/// let llvm_mod = @TinyMoonBit.compile(code)
/// // IRTranslate
/// let rv64 = ArchConfig::riscv64()
/// let mir_mod = Module::new(rv64)
/// mir_mod.translate_llvm_module(llvm_mod)
/// let mir_func = mir_mod.get_function("demo").unwrap()
/// let expected =
///   #|func demo(a0, a1) {
///   #|entry:
///   #|  v0 = move.i64 a0
///   #|  v1 = move.i64 a1
///   #|  v2 = lt.i32 v0, v1
///   #|  v3 = le.i32 v0, v1
///   #|  v4 = gt.i32 v0, v1
///   #|  v5 = ge.i32 v0, v1
///   #|  v6 = eq.i32 v0, v1
///   #|  v7 = ne.i32 v0, v1
///   #|  ret
///   #|}
///   #|
///
/// inspect(mir_func, content=expected)
/// ```
pub fn translate_llvm_icmp_inst(
  llvm_inst : @IR.ICmpInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  // If the ICmpInst is only used by a BranchInst,
  // we do not generate a separate instruction for it.
  let inst_users = llvm_inst.getUsers().unwrap()
  if inst_users.length() == 1 && inst_users[0].asValueEnum() is BranchInst(_) {
    return []
  }
  let { predicate, lhs, rhs, .. } = llvm_inst
  let opcode : ICmpOpCode = match predicate {
    EQ => Eq
    NE => Ne
    SGT => Gt
    SGE => Ge
    SLT => Lt
    SLE => Le
    UGT => Gtu
    UGE => Geu
    ULT => Ltu
    ULE => Leu
  }
  guard func.get_operand_from_llvm_value(lhs) is Some(lhs_op) else {
    raise IRTranslateError("ICmpInst: lhs operand not found in value_map")
  }
  guard func.get_operand_from_llvm_value(rhs) is Some(rhs_op) else {
    raise IRTranslateError("ICmpInst: rhs operand not found in value_map")
  }
  guard func.get_operand_from_llvm_value(llvm_inst) is Some(dst_op) else {
    raise IRTranslateError(
      "ICmpInst: destination operand not found in value_map",
    )
  }
  guard dst_op is IRegister(dst) else {
    raise IRTranslateError(
      "ICmpInst: destination operand is not an integer register",
    )
  }
  let data_size = data_layout.getTypeAllocSizeInBits(lhs.getType())
  match (lhs_op, rhs_op) {
    (IRegister(src1), IRegister(src2)) =>
      [builder.build_icmp(opcode, data_size, dst~, src1~, src2~)]
    (IRegister(src1), Imm(src2_imm)) => {
      let src2 = func.new_virtual_reg()
      [
        builder.build_imove_imm(data_size, dst=src2, src=src2_imm),
        builder.build_icmp(opcode, data_size, dst~, src1~, src2~),
      ]
    }
    (Imm(src1_imm), IRegister(src2)) => {
      let src1 = func.new_virtual_reg()
      [
        builder.build_imove_imm(data_size, dst=src1, src=src1_imm),
        builder.build_icmp(opcode, data_size, dst~, src1~, src2~),
      ]
    }
    (Imm(src1), Imm(src2)) => {
      let src = match opcode {
        Eq => if src1 == src2 { 1L } else { 0L }
        Ne => if src1 != src2 { 1L } else { 0L }
        Gt => if src1 > src2 { 1L } else { 0L }
        Ge => if src1 >= src2 { 1L } else { 0L }
        Lt => if src1 < src2 { 1L } else { 0L }
        Le => if src1 <= src2 { 1L } else { 0L }
        Gtu =>
          if src1.reinterpret_as_uint64() > src2.reinterpret_as_uint64() {
            1L
          } else {
            0L
          }
        Geu =>
          if src1.reinterpret_as_uint64() >= src2.reinterpret_as_uint64() {
            1L
          } else {
            0L
          }
        Ltu =>
          if src1.reinterpret_as_uint64() < src2.reinterpret_as_uint64() {
            1L
          } else {
            0L
          }
        Leu =>
          if src1.reinterpret_as_uint64() <= src2.reinterpret_as_uint64() {
            1L
          } else {
            0L
          }
      }
      [builder.build_imove_imm(data_size, dst~, src~)]
    }
    opcode =>
      raise IRTranslateError(
        "Unsupported operand types for integer comparison: \{opcode}",
      )
  }
}

///|
///
/// test "FCmp IRTranslate Test" {
///   let code = 
///     #|fn demo(a: Float, b: Float) -> Unit {
///     #|  let c = a < b
///     #|  let d = a <= b
///     #|  let e = a > b
///     #|  let f = a >= b
///     #|  let g = a == b
///     #|  let h = a != b
///     #|  return
///     #|}
///   let llvm_mod = @TinyMoonBit.compile(code)
///   // IRTranslate
///   let mir_mod = Module::new(rv64)
///   mir_mod.translate_llvm_module(llvm_mod)
///   let mir_func = mir_mod.get_function("demo").unwrap()
///   let expected =
///     #|func demo(fa0, fa1) {
///     #|entry:
///     #|  v0 = flt.f32 fa0, fa1
///     #|  v1 = fle.f32 fa0, fa1
///     #|  v2 = fgt.f32 fa0, fa1
///     #|  v3 = fge.f32 fa0, fa1
///     #|  v4 = feq.f32 fa0, fa1
///     #|  v5 = fne.f32 fa0, fa1
///     #|  ret
///     #|}
///     #|
/// 
///   inspect(mir_func, content=expected)
/// }
/// ```
pub fn translate_llvm_fcmp_inst(
  llvm_inst : @IR.FCmpInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  guard func.get_operand_from_llvm_value(llvm_inst) is Some(dst_op) else {
    raise IRTranslateError(
      "FCmpInst: destination operand not found in value_map",
    )
  }
  guard dst_op is IRegister(dst) else {
    raise IRTranslateError(
      "FCmpInst: destination operand is not an integer register",
    )
  }
  let { predicate, lhs, rhs, .. } = llvm_inst
  match predicate {
    FALSE => return [builder.build_imove_imm(64, dst~, src=0L)]
    TRUE => return [builder.build_imove_imm(64, dst~, src=1L)]
    _ => ()
  }
  let opcode : FCmpOpCode = match predicate {
    OEQ => Feq
    OGT => Fgt
    OGE => Fge
    OLT => Flt
    OLE => Fle
    ONE => Fne
    UEQ => Feq // unordered or equal
    UGT => Fgt // unordered or greater than
    UGE => Fge // unordered or greater than or equal
    ULT => Flt // unordered or less than
    ULE => Fle // unordered or less than or equal
    UNE => Fne // unordered or not equal
    _ =>
      raise IRTranslateError("Unsupported floating-point comparison predicate")
  }
  guard func.get_operand_from_llvm_value(lhs) is Some(lhs_op) else {
    raise IRTranslateError("FCmpInst: lhs operand not found in value_map")
  }
  guard func.get_operand_from_llvm_value(rhs) is Some(rhs_op) else {
    raise IRTranslateError("FCmpInst: rhs operand not found in value_map")
  }
  let data_size = data_layout.getTypeAllocSizeInBits(lhs.getType())
  match (lhs_op, rhs_op) {
    (FRegister(src1), FRegister(src2)) =>
      [builder.build_fcmp(opcode, data_size, dst~, src1~, src2~)]
    (FRegister(src1), FImm(f)) => {
      let ireg = func.new_virtual_reg()
      let src2 = func.new_virtual_freg()
      [
        builder.build_imove_imm(
          data_size,
          dst=ireg,
          src=f.reinterpret_as_int64(),
        ),
        builder.build_fmove_from_ireg(data_size, dst=src2, src=ireg),
        builder.build_fcmp(opcode, data_size, dst~, src1~, src2~),
      ]
    }
    (FImm(f1), FRegister(src2)) => {
      let src1 = func.new_virtual_freg()
      let ireg = func.new_virtual_reg()
      [
        builder.build_imove_imm(
          data_size,
          dst=ireg,
          src=f1.reinterpret_as_int64(),
        ),
        builder.build_fmove_from_ireg(data_size, dst=src1, src=ireg),
        builder.build_fcmp(opcode, data_size, dst~, src1~, src2~),
      ]
    }
    (FImm(f1), FImm(f2)) => {
      let src = match opcode {
        Feq => if f1 == f2 { 1L } else { 0L }
        Fne => if f1 != f2 { 1L } else { 0L }
        Fgt => if f1 > f2 { 1L } else { 0L }
        Fge => if f1 >= f2 { 1L } else { 0L }
        Flt => if f1 < f2 { 1L } else { 0L }
        Fle => if f1 <= f2 { 1L } else { 0L }
      }
      [builder.build_imove_imm(data_size, dst~, src~)]
    }
    (lhs_op, rhs_op) =>
      raise IRTranslateError(
        "Unsupported operand types for floating-point comparison: \{lhs_op}, \{rhs_op}",
      )
  }
}

///|
///
/// IRTranslate from LLVM IR to MoonMIR for BranchInst.
///
/// ```mbt
/// let code = 
///   #|fn demo(a: Int, b: Int) -> Int {
///   #|  if a < b {
///   #|    return a
///   #|  }
///   #|  return b
///   #|}
/// let llvm_mod = @TinyMoonBit.compile(code)
/// // IRTranslate
/// let rv64 = ArchConfig::riscv64()
/// let mir_mod = Module::new(rv64)
/// mir_mod.translate_llvm_module(llvm_mod)
/// let mir_func = mir_mod.get_function("demo").unwrap()
/// let expected = 
///   #|func demo(a0, a1) {
///   #|entry:
///   #|  v0 = move.i64 a0
///   #|  v1 = move.i64 a1
///   #|  blt v0, v1, demo_L1, demo_L2
///   #|
///   #|; preds: entry
///   #|demo_L1:
///   #|  a0 = move.i64 v0
///   #|  ret
///   #|
///   #|; preds: entry
///   #|demo_L2:
///   #|  jmp demo_L3
///   #|
///   #|; preds: demo_L2
///   #|demo_L3:
///   #|  a0 = move.i64 v1
///   #|  ret
///   #|}
///   #|
/// 
/// inspect(mir_func, content=expected)
/// ```
pub fn translate_llvm_branch_inst(
  llvm_inst : @IR.BranchInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  match llvm_inst.condition {
    Some(_) =>
      translate_llvm_conditional_branch(llvm_inst, builder, func, data_layout)
    None => translate_llvm_unconditional_branch(llvm_inst, builder, func)
  }
}

///|
///
/// IRTranslate from LLVM IR to MoonMIR for conditional BranchInst.
///
/// ```mbt
/// let code = 
///   #|fn demo(a: Int, b: Int) -> Int {
///   #|  if a < b {
///   #|    return a
///   #|  }
///   #|  return b
///   #|}
/// let llvm_mod = @TinyMoonBit.compile(code)
/// // IRTranslate
/// let rv64 = ArchConfig::riscv64()
/// let mir_mod = Module::new(rv64)
/// mir_mod.translate_llvm_module(llvm_mod)
/// let mir_func = mir_mod.get_function("demo").unwrap()
/// let expected = 
///   #|func demo(a0, a1) {
///   #|entry:
///   #|  v0 = move.i64 a0
///   #|  v1 = move.i64 a1
///   #|  blt v0, v1, demo_L1, demo_L2
///   #|
///   #|; preds: entry
///   #|demo_L1:
///   #|  a0 = move.i64 v0
///   #|  ret
///   #|
///   #|; preds: entry
///   #|demo_L2:
///   #|  jmp demo_L3
///   #|
///   #|; preds: demo_L2
///   #|demo_L3:
///   #|  a0 = move.i64 v1
///   #|  ret
///   #|}
///   #|
/// 
/// inspect(mir_func, content=expected)
/// ```
pub fn translate_llvm_conditional_branch(
  llvm_inst : @IR.BranchInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  guard llvm_inst
    is {
      condition: Some(cond),
      trueBlock: Some(truebb),
      falseBlock: Some(falsebb),
      ..,
    } else {
    raise IRTranslateError("BranchInst: Invalid conditional branch instruction")
  }
  guard func.get_operand_from_llvm_value(truebb) is Some(true_op) else {
    raise IRTranslateError(
      "BranchInst: trueBlock operand not found in value_map",
    )
  }
  guard func.get_operand_from_llvm_value(falsebb) is Some(false_op) else {
    raise IRTranslateError(
      "BranchInst: falseBlock operand not found in value_map",
    )
  }
  guard true_op is Label(true_label) else {
    raise IRTranslateError("BranchInst: trueBlock operand is not a label")
  }
  guard false_op is Label(false_label) else {
    raise IRTranslateError("BranchInst: falseBlock operand is not a label")
  }
  // Push the successors and predecessors
  let machine_true_bb = func.bbmap.get(true_label).unwrap()
  let machine_false_bb = func.bbmap.get(false_label).unwrap()
  let current_bb = builder.bb
  machine_true_bb.preds.push(current_bb)
  machine_false_bb.preds.push(current_bb)
  current_bb.succs.push(machine_true_bb)
  current_bb.succs.push(machine_false_bb)
  if !(cond.asValueEnum() is ICmpInst(_)) {
    guard func.get_operand_from_llvm_value(cond) is Some(cond_op) else {
      raise IRTranslateError(
        "BranchInst: condition operand not found in value_map",
      )
    }
    guard cond_op is IRegister(lhs) else {
      raise IRTranslateError(
        "BranchInst: condition operand is not an integer register",
      )
    }
    let minst = builder.build_branch_imm(
      Bne,
      lhs~,
      rhs=0L,
      true_label~,
      false_label~,
    )
    return [minst]
  }

  //
  let cmp_users = cond.getUsers().unwrap()
  let cmp_only_used_in_branch = cmp_users.length() == 1 &&
    cmp_users[0].asValueEnum() is BranchInst(_)

  // If the comparison instruction is not only used in this branch,
  // generate Bne directly.
  if !cmp_only_used_in_branch {
    guard func.get_operand_from_llvm_value(cond) is Some(cond_op) else {
      raise IRTranslateError(
        "BranchInst: condition operand not found in value_map",
      )
    }
    guard cond_op is IRegister(lhs) else {
      raise IRTranslateError(
        "BranchInst: condition operand is not an integer register",
      )
    }
    let minst = builder.build_branch_imm(
      Bne,
      lhs~,
      rhs=0L,
      true_label~,
      false_label~,
    )
    return [minst]
  }

  // If the comparison instruction only used in this branch,
  // generate breach with the comparison.
  guard cond.asValueEnum() is ICmpInst({ predicate, lhs, rhs, .. })
  let opcode = match predicate {
    EQ => Beq
    NE => Bne
    SGT => Bgt
    SGE => Bge
    SLT => Blt
    SLE => Ble
    UGT => Bgtu
    UGE => Bgeu
    ULT => Bltu
    ULE => Bleu
  }
  guard func.get_operand_from_llvm_value(lhs) is Some(lhs_op) else {
    raise IRTranslateError("BranchInst: lhs operand not found in value_map")
  }
  guard func.get_operand_from_llvm_value(rhs) is Some(rhs_op) else {
    raise IRTranslateError("BranchInst: rhs operand not found in value_map")
  }
  let data_size = data_layout.getTypeAllocSizeInBits(lhs.getType())
  match (lhs_op, rhs_op) {
    (IRegister(lhs), IRegister(rhs)) =>
      [builder.build_branch(opcode, lhs~, rhs~, true_label~, false_label~)]
    (IRegister(lhs), Imm(rhs)) =>
      [builder.build_branch_imm(opcode, lhs~, rhs~, true_label~, false_label~)]
    (Imm(lhs_imm), IRegister(rhs)) => {
      let lhs = func.new_virtual_reg()
      [
        builder.build_imove_imm(data_size, dst=lhs, src=lhs_imm),
        builder.build_branch(opcode, lhs~, rhs~, true_label~, false_label~),
      ]
    }
    (Imm(lhs), Imm(rhs)) => {
      let take_true_branch = match opcode {
        Beq => lhs == rhs
        Bne => lhs != rhs
        Bgt => lhs > rhs
        Bge => lhs >= rhs
        Blt => lhs < rhs
        Ble => lhs <= rhs
        Bgtu => lhs.reinterpret_as_uint64() > rhs.reinterpret_as_uint64()
        Bgeu => lhs.reinterpret_as_uint64() >= rhs.reinterpret_as_uint64()
        Bltu => lhs.reinterpret_as_uint64() < rhs.reinterpret_as_uint64()
        // Bleu
        _ => lhs.reinterpret_as_uint64() <= rhs.reinterpret_as_uint64()
      }
      let target_label = if take_true_branch { true_label } else { false_label }
      [builder.build_jmp(target_label~)]
    }
    (lhs_op, rhs_op) =>
      raise IRTranslateError(
        "Unsupported operand types for integer comparison in BranchInst: \{lhs_op}, \{rhs_op}",
      )
  }
}

///|
///
/// IRTranslate from LLVM IR to MoonMIR for unconditional BranchInst.
///
/// ```mbt
/// let code = 
///   #|fn demo(a: Int, b: Int) -> Int {
///   #|  if a < b {
///   #|    return a
///   #|  }
///   #|  return b
///   #|}
/// let llvm_mod = @TinyMoonBit.compile(code)
/// // IRTranslate
/// let rv64 = ArchConfig::riscv64()
/// let mir_mod = Module::new(rv64)
/// mir_mod.translate_llvm_module(llvm_mod)
/// let mir_func = mir_mod.get_function("demo").unwrap()
/// let expected = 
///   #|func demo(a0, a1) {
///   #|entry:
///   #|  v0 = move.i64 a0
///   #|  v1 = move.i64 a1
///   #|  blt v0, v1, demo_L1, demo_L2
///   #|
///   #|; preds: entry
///   #|demo_L1:
///   #|  a0 = move.i64 v0
///   #|  ret
///   #|
///   #|; preds: entry
///   #|demo_L2:
///   #|  jmp demo_L3
///   #|
///   #|; preds: demo_L2
///   #|demo_L3:
///   #|  a0 = move.i64 v1
///   #|  ret
///   #|}
///   #|
/// 
/// inspect(mir_func, content=expected)
/// ```
pub fn translate_llvm_unconditional_branch(
  llvm_inst : @IR.BranchInst,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  guard llvm_inst
    is { condition: None, trueBlock: Some(targetBB), falseBlock: None, .. } else {
    raise IRTranslateError(
      "BranchInst: Invalid unconditional branch instruction",
    )
  }
  guard func.get_operand_from_llvm_value(targetBB) is Some(target_op) else {
    raise IRTranslateError(
      "BranchInst: trueBlock operand not found in value_map",
    )
  }
  guard target_op is Label(target_label) else {
    raise IRTranslateError("BranchInst: trueBlock operand is not a label")
  }
  let machine_target_bb = func.bbmap.get(target_label).unwrap()
  let current_bb = builder.bb
  machine_target_bb.preds.push(current_bb)
  current_bb.succs.push(machine_target_bb)
  let minst = builder.build_jmp(target_label~)
  [minst]
}

///|
pub fn translate_llvm_switch_inst(
  llvm_inst : @IR.SwitchInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  if false {
    raise IRTranslateError("SwitchInst translation not implemented yet")
  }
  ignore(llvm_inst)
  ignore(builder)
  ignore(func)
  ignore(data_layout)
  []
}

///|
pub fn translate_llvm_cast_inst(
  llvm_inst : @IR.CastInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  let { opcode, from_val, to_ty, .. } = llvm_inst
  guard func.get_operand_from_llvm_value(from_val) is Some(from_op) else {
    raise IRTranslateError("CastInst: source operand not found in value_map")
  }
  let from_ty_size = data_layout.getTypeAllocSizeInBits(from_val.getType())
  let to_ty_size = data_layout.getTypeAllocSizeInBits(to_ty)
  guard func.get_operand_from_llvm_value(llvm_inst) is Some(dst_op) else {
    raise IRTranslateError(
      "CastInst: destination operand not found in value_map",
    )
  }
  match opcode {
    Trunc =>
      translate_trunc(from_ty_size, to_ty_size, from_op, dst_op, builder, func)
    SExt =>
      translate_sext(from_ty_size, to_ty_size, from_op, dst_op, builder, func)
    ZExt =>
      translate_zext(from_ty_size, to_ty_size, from_op, dst_op, builder, func)
    FPTrunc =>
      translate_fptrunc(
        from_ty_size, to_ty_size, from_op, dst_op, builder, func,
      )
    FPExt =>
      translate_fpext(from_ty_size, to_ty_size, from_op, dst_op, builder, func)
    UIToFP =>
      translate_uitofp(from_ty_size, to_ty_size, from_op, dst_op, builder, func)
    SIToFP =>
      translate_sitofp(from_ty_size, to_ty_size, from_op, dst_op, builder, func)
    FPToUI =>
      translate_fptoui(from_ty_size, to_ty_size, from_op, dst_op, builder, func)
    FPToSI =>
      translate_fptosi(from_ty_size, to_ty_size, from_op, dst_op, builder, func)
    PtrToInt => translate_bitcast(64, from_op, dst_op, builder, func)
    IntToPtr => translate_bitcast(64, from_op, dst_op, builder, func)
    BitCast => translate_bitcast(from_ty_size, from_op, dst_op, builder, func)
  }
}

///|
pub fn translate_trunc(
  from_ty_size : Int,
  to_ty_size : Int,
  from_op : Operand,
  dst_op : Operand,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  match (dst_op, from_op) {
    (IRegister(dst), IRegister(src)) =>
      [builder.build_trunc(from_ty_size~, to_ty_size~, dst~, src~)]
    (IRegister(dst), Imm(src_imm)) => {
      let src = func.new_virtual_reg()
      [
        builder.build_imove_imm(from_ty_size, dst=src, src=src_imm),
        builder.build_trunc(from_ty_size~, to_ty_size~, dst~, src~),
      ]
    }
    (dst_op, from_op) =>
      raise IRTranslateError(
        "Trunc: Unsupported operand types for truncation, got \{dst_op}, \{from_op}",
      )
  }
}

///|
pub fn translate_sext(
  from_ty_size : Int,
  to_ty_size : Int,
  from_op : Operand,
  dst_op : Operand,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  match (dst_op, from_op) {
    (IRegister(dst), IRegister(src)) =>
      [builder.build_sext(from_ty_size~, to_ty_size~, dst~, src~)]
    (IRegister(dst), Imm(src_imm)) => {
      let src = func.new_virtual_reg()
      [
        builder.build_imove_imm(from_ty_size, dst=src, src=src_imm),
        builder.build_sext(from_ty_size~, to_ty_size~, dst~, src~),
      ]
    }
    (dst_op, from_op) =>
      raise IRTranslateError(
        "SExt: Unsupported operand types for sign extension, got \{dst_op}, \{from_op}",
      )
  }
}

///|
pub fn translate_zext(
  from_ty_size : Int,
  to_ty_size : Int,
  from_op : Operand,
  dst_op : Operand,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  match (dst_op, from_op) {
    (IRegister(dst), IRegister(src)) =>
      [builder.build_zext(from_ty_size~, to_ty_size~, dst~, src~)]
    (IRegister(dst), Imm(src_imm)) => {
      let src = func.new_virtual_reg()
      [
        builder.build_imove_imm(from_ty_size, dst=src, src=src_imm),
        builder.build_zext(from_ty_size~, to_ty_size~, dst~, src~),
      ]
    }
    (dst_op, from_op) =>
      raise IRTranslateError(
        "ZExt: Unsupported operand types for zero extension, got \{dst_op}, \{from_op}",
      )
  }
}

///|
pub fn translate_fptrunc(
  from_ty_size : Int,
  to_ty_size : Int,
  from_op : Operand,
  dst_op : Operand,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  match (dst_op, from_op) {
    (FRegister(dst), FRegister(src)) =>
      [builder.build_fptrunc(from_ty_size~, to_ty_size~, dst~, src~)]
    (FRegister(dst), FImm(src_imm)) => {
      let src = func.new_virtual_freg()
      let ireg = func.new_virtual_reg()
      [
        builder.build_imove_imm(
          from_ty_size,
          dst=ireg,
          src=src_imm.reinterpret_as_int64(),
        ),
        builder.build_fmove_from_ireg(from_ty_size, dst=src, src=ireg),
        builder.build_fptrunc(from_ty_size~, to_ty_size~, dst~, src~),
      ]
    }
    (dst_op, from_op) =>
      raise IRTranslateError(
        "FPTrunc: Unsupported operand types for floating-point truncation, got \{dst_op}, \{from_op}",
      )
  }
}

///|
pub fn translate_fpext(
  from_ty_size : Int,
  to_ty_size : Int,
  from_op : Operand,
  dst_op : Operand,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  match (dst_op, from_op) {
    (FRegister(dst), FRegister(src)) =>
      [builder.build_fpext(from_ty_size~, to_ty_size~, dst~, src~)]
    (FRegister(dst), FImm(src_imm)) => {
      let src = func.new_virtual_freg()
      let ireg = func.new_virtual_reg()
      [
        builder.build_imove_imm(
          from_ty_size,
          dst=ireg,
          src=src_imm.reinterpret_as_int64(),
        ),
        builder.build_fmove_from_ireg(from_ty_size, dst=src, src=ireg),
        builder.build_fpext(from_ty_size~, to_ty_size~, dst~, src~),
      ]
    }
    (dst_op, from_op) =>
      raise IRTranslateError(
        "FPExt: Unsupported operand types for floating-point extension, got \{dst_op}, \{from_op}",
      )
  }
}

///|
pub fn translate_uitofp(
  from_ty_size : Int,
  to_ty_size : Int,
  from_op : Operand,
  dst_op : Operand,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  match (dst_op, from_op) {
    (FRegister(dst), IRegister(src)) =>
      [builder.build_ui_to_fp(from_ty_size~, to_ty_size~, dst~, src~)]
    (FRegister(dst), Imm(src_imm)) => {
      let src = func.new_virtual_reg()
      [
        builder.build_imove_imm(from_ty_size, dst=src, src=src_imm),
        builder.build_ui_to_fp(from_ty_size~, to_ty_size~, dst~, src~),
      ]
    }
    (dst_op, from_op) =>
      raise IRTranslateError(
        "UIToFP: Unsupported operand types for unsigned integer to floating-point conversion, got \{dst_op}, \{from_op}",
      )
  }
}

///|
pub fn translate_sitofp(
  from_ty_size : Int,
  to_ty_size : Int,
  from_op : Operand,
  dst_op : Operand,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  match (dst_op, from_op) {
    (FRegister(dst), IRegister(src)) =>
      [builder.build_si_to_fp(from_ty_size~, to_ty_size~, dst~, src~)]
    (FRegister(dst), Imm(src_imm)) => {
      let src = func.new_virtual_reg()
      [
        builder.build_imove_imm(from_ty_size, dst=src, src=src_imm),
        builder.build_si_to_fp(from_ty_size~, to_ty_size~, dst~, src~),
      ]
    }
    (dst_op, from_op) =>
      raise IRTranslateError(
        "SIToFP: Unsupported operand types for signed integer to floating-point conversion, got \{dst_op}, \{from_op}",
      )
  }
}

///|
pub fn translate_fptoui(
  from_ty_size : Int,
  to_ty_size : Int,
  from_op : Operand,
  dst_op : Operand,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  match (dst_op, from_op) {
    (IRegister(dst), FRegister(src)) =>
      [builder.build_fp_to_ui(from_ty_size~, to_ty_size~, dst~, src~)]
    (IRegister(dst), FImm(src_imm)) => {
      let src = func.new_virtual_freg()
      let ireg = func.new_virtual_reg()
      [
        builder.build_imove_imm(
          from_ty_size,
          dst=ireg,
          src=src_imm.reinterpret_as_int64(),
        ),
        builder.build_fmove_from_ireg(from_ty_size, dst=src, src=ireg),
        builder.build_fp_to_ui(from_ty_size~, to_ty_size~, dst~, src~),
      ]
    }
    (dst_op, from_op) =>
      raise IRTranslateError(
        "FPToUI: Unsupported operand types for floating-point to unsigned integer conversion, got \{dst_op}, \{from_op}",
      )
  }
}

///|
pub fn translate_fptosi(
  from_ty_size : Int,
  to_ty_size : Int,
  from_op : Operand,
  dst_op : Operand,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  match (dst_op, from_op) {
    (IRegister(dst), FRegister(src)) =>
      [builder.build_fp_to_si(from_ty_size~, to_ty_size~, dst~, src~)]
    (IRegister(dst), FImm(src_imm)) => {
      let src = func.new_virtual_freg()
      let ireg = func.new_virtual_reg()
      [
        builder.build_imove_imm(
          from_ty_size,
          dst=ireg,
          src=src_imm.reinterpret_as_int64(),
        ),
        builder.build_fmove_from_ireg(from_ty_size, dst=src, src=ireg),
        builder.build_fp_to_si(from_ty_size~, to_ty_size~, dst~, src~),
      ]
    }
    (dst_op, from_op) =>
      raise IRTranslateError(
        "FPToSI: Unsupported operand types for floating-point to signed integer conversion, got \{dst_op}, \{from_op}",
      )
  }
}

// MIR has no bitcast instruction
// Use Move, FMoveI, IMoveF, Load, Store, etc. to implement BitCast

///|
pub fn translate_bitcast(
  data_size : Int,
  from_op : Operand,
  dst_op : Operand,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  match (dst_op, from_op) {
    (IRegister(dst), IRegister(src)) =>
      [builder.build_imove(data_size, dst~, src~)]
    (IRegister(dst), Imm(src_imm)) =>
      [builder.build_imove_imm(data_size, dst~, src=src_imm)]
    (FRegister(dst), FRegister(src)) =>
      [builder.build_fmove(data_size, dst~, src~)]
    (FRegister(dst), FImm(src_imm)) => {
      let ireg = func.new_virtual_reg()
      [
        builder.build_imove_imm(
          data_size,
          dst=ireg,
          src=src_imm.reinterpret_as_int64(),
        ),
        builder.build_fmove_from_ireg(data_size, dst~, src=ireg),
      ]
    }
    (FRegister(dst), IRegister(src)) =>
      [builder.build_fmove_from_ireg(data_size, dst~, src~)]
    (IRegister(dst), FRegister(src)) =>
      [builder.build_fmove_to_ireg(data_size, dst~, src~)]
    (FRegister(dst), Imm(src_imm)) => {
      let ireg = func.new_virtual_reg()
      [
        builder.build_imove_imm(data_size, dst=ireg, src=src_imm),
        builder.build_fmove_from_ireg(data_size, dst~, src=ireg),
      ]
    }
    (IRegister(dst), FImm(src_imm)) => {
      let freg = func.new_virtual_freg()
      [
        builder.build_imove_imm(
          data_size,
          dst~,
          src=src_imm.reinterpret_as_int64(),
        ),
        builder.build_fmove_to_ireg(data_size, dst~, src=freg),
      ]
    }
    (dst_op, from_op) =>
      raise IRTranslateError(
        "BitCast: Unsupported operand types for bitcast, got \{dst_op}, \{from_op}",
      )
  }
}

///|
pub fn translate_llvm_gep_inst(
  llvm_inst : @IR.GetElementPtrInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  raise IRTranslateError("GetElementPtrInst translation not implemented yet")
  ignore(llvm_inst)
  ignore(builder)
  ignore(func)
  ignore(data_layout)
  []
}

///|
pub fn translate_llvm_select_inst(
  llvm_inst : @IR.SelectInst,
  builder : IRBuilder,
  func : Function,
  data_layout : @IR.DataLayout,
) -> Array[Instruction] raise MIRError {
  raise IRTranslateError("SelectInst translation not implemented yet")
  ignore(llvm_inst)
  ignore(builder)
  ignore(func)
  ignore(data_layout)
  []
}

///|
pub fn translate_llvm_return_inst(
  llvm_inst : @IR.ReturnInst,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  func.terminal_blocks.push(builder.bb)
  let { retVal, .. } = llvm_inst
  guard retVal is Some(retVal) else {
    let minst = builder.build_ret()
    return [minst]
  }
  guard func.get_operand_from_llvm_value(retVal) is Some(ret_op) else {
    raise IRTranslateError(
      "ReturnInst: return value operand not found in value_map",
    )
  }
  match ret_op {
    IRegister(ret) if !(ret is AReg(0)) => {
      let minst = builder.build_imove(64, dst=AReg(0), src=ret)
      return [minst, builder.build_ret()]
    }
    IRegister(_) => [builder.build_ret()]
    FRegister(ret) if !(ret is FAReg(0)) => {
      let minst = builder.build_fmove(64, dst=FAReg(0), src=ret)
      return [minst, builder.build_ret()]
    }
    FRegister(_) => [builder.build_ret()]
    Imm(ret) => {
      let minst = builder.build_imove_imm(64, dst=AReg(0), src=ret)
      return [minst, builder.build_ret()]
    }
    FImm(ret) => {
      let ireg = func.new_virtual_reg()
      let freg = func.new_virtual_freg()
      [
        builder.build_imove_imm(64, dst=ireg, src=ret.reinterpret_as_int64()),
        builder.build_fmove_from_ireg(64, dst=freg, src=ireg),
        builder.build_fmove(64, dst=FAReg(0), src=freg),
        builder.build_ret(),
      ]
    }
    Label(label) => {
      let minst = builder.build_load_addr(AReg(0), label)
      [minst, builder.build_ret()]
    }
    ret_op =>
      raise IRTranslateError(
        "ReturnInst: Unsupported operand type for return value \{ret_op}",
      )
  }
}

///|
///
/// IRTranslate from LLVM IR to MoonMIR for CallInst.
///
/// ```mbt
/// let code = 
///   #|fn add(x: Int, y: Int) -> Int {
///   #|  x + y
///   #|}
///   #|
///   #|fn demo() -> Int {
///   #|  let a = add(10, 20)
///   #|  return a
///   #|}
/// let llvm_mod = @TinyMoonBit.compile(code)
/// // IRTranslate
/// let rv64 = ArchConfig::riscv64()
/// let mir_mod = Module::new(rv64)
/// mir_mod.translate_llvm_module(llvm_mod)
/// let mir_func = mir_mod.get_function("demo").unwrap()
/// inspect(mir_func, content=(
///   #|func demo() {
///   #|entry:
///   #|  a0 = move.i64 10
///   #|  a1 = move.i64 20
///   #|  call add, a0, a1
///   #|  v0 = move.i64 a0
///   #|  a0 = move.i64 v0
///   #|  ret
///   #|}
///   #|
/// ))
///
/// ```
pub fn translate_llvm_call_inst(
  llvm_inst : @IR.CallInst,
  builder : IRBuilder,
  func : Function,
) -> Array[Instruction] raise MIRError {
  let { callee, args, .. } = llvm_inst
  let { num_arg_regs, num_arg_fregs, .. } = func.mod.arch_config
  let callee_name = callee.getName().unwrap()
  let mut call_ireg_cnt = 0
  let mut call_freg_cnt = 0
  let minsts : Array[Instruction] = Array::new()
  for arg in args {
    guard func.get_operand_from_llvm_value(arg) is Some(arg_op) else {
      raise IRTranslateError(
        "CallInst: argument operand not found in value_map",
      )
    }
    let arg_is_fp = arg.getType().isIEEELikeFPTy()
    match (arg_op, arg_is_fp) {
      (IRegister(src), false) if call_ireg_cnt < num_arg_regs => {
        let dst = AReg(call_ireg_cnt)
        let inst = builder.build_imove(64, dst~, src~)
        if src != dst {
          minsts.push(inst)
        }
        call_ireg_cnt += 1
      }
      (IRegister(src), false) => {
        let _ = func.extend_var_stack(8L, 8L)
        let stack_offset = 8L * (call_ireg_cnt - num_arg_regs).to_int64()
        let inst = builder.build_storei(
          64,
          src~,
          base=StackPtr,
          offset=stack_offset,
        )
        minsts.push(inst)
        call_ireg_cnt += 1
      }
      (FRegister(src), true) if call_freg_cnt < num_arg_fregs => {
        let dst = FAReg(call_freg_cnt)
        let inst = builder.build_fmove(64, dst~, src~)
        if src != dst {
          minsts.push(inst)
        }
        minsts.push(inst)
        call_freg_cnt += 1
      }
      (FRegister(src), true) => {
        let _ = func.extend_var_stack(8L, 8L)
        let stack_offset = 8L * (call_freg_cnt - num_arg_fregs).to_int64()
        let inst = builder.build_storef(
          64,
          src~,
          base=StackPtr,
          offset=stack_offset,
        )
        minsts.push(inst)
        call_freg_cnt += 1
      }
      (Imm(src), false) if call_ireg_cnt < num_arg_regs => {
        let dst = AReg(call_ireg_cnt)
        let inst = builder.build_imove_imm(64, dst~, src~)
        minsts.push(inst)
        call_ireg_cnt += 1
      }
      (Imm(src), false) => {
        let _ = func.extend_var_stack(8L, 8L)
        let stack_offset = 8L * (call_ireg_cnt - num_arg_regs).to_int64()
        let vreg = func.new_virtual_reg()
        let inst1 = builder.build_imove_imm(64, dst=vreg, src~)
        let inst2 = builder.build_storei(
          64,
          src=vreg,
          base=StackPtr,
          offset=stack_offset,
        )
        minsts.push(inst1)
        minsts.push(inst2)
        call_ireg_cnt += 1
      }
      (FImm(src), true) if call_freg_cnt < num_arg_fregs => {
        let dst = FAReg(call_freg_cnt)
        let ireg = func.new_virtual_reg()
        let inst1 = builder.build_imove_imm(
          64,
          dst=ireg,
          src=src.reinterpret_as_int64(),
        )
        let inst2 = builder.build_fmove_from_ireg(64, dst~, src=ireg)
        minsts.push(inst1)
        minsts.push(inst2)
        call_freg_cnt += 1
      }
      (FImm(src), true) => {
        let _ = func.extend_var_stack(8L, 8L)
        let stack_offset = 8L * (call_freg_cnt - num_arg_fregs).to_int64()
        let ireg = func.new_virtual_reg()
        let inst1 = builder.build_imove_imm(
          64,
          dst=ireg,
          src=src.reinterpret_as_int64(),
        )
        let inst2 = builder.build_storei(
          64,
          src=ireg,
          base=StackPtr,
          offset=stack_offset,
        )
        minsts.push(inst1)
        minsts.push(inst2)
        call_freg_cnt += 1
      }
      (Label(label), false) if call_ireg_cnt < num_arg_regs => {
        let dst = AReg(call_ireg_cnt)
        let inst = builder.build_load_addr(dst, label)
        minsts.push(inst)
        call_ireg_cnt += 1
      }
      (Label(label), false) => {
        let _ = func.extend_var_stack(8L, 8L)
        let stack_offset = 8L * (call_ireg_cnt - num_arg_regs).to_int64()
        let vreg = func.new_virtual_reg()
        let inst1 = builder.build_load_addr(vreg, label)
        let inst2 = builder.build_storei(
          64,
          src=vreg,
          base=StackPtr,
          offset=stack_offset,
        )
        minsts.push(inst1)
        minsts.push(inst2)
        call_ireg_cnt += 1
      }
      (Mem(base, offset), false) if call_ireg_cnt < num_arg_regs => {
        // Memory address as argument - compute effective address and pass in register
        let dst = AReg(call_ireg_cnt)
        let vreg = func.new_virtual_reg()
        // Compute effective address: base + offset
        if offset == 0L {
          let inst = builder.build_imove(64, dst~, src=base)
          minsts.push(inst)
        } else {
          let inst1 = builder.build_ibinary_imm(
            Add,
            64,
            dst=vreg,
            src1=base,
            src2=offset,
          )
          let inst2 = builder.build_imove(64, dst~, src=vreg)
          minsts.push(inst1)
          minsts.push(inst2)
        }
        call_ireg_cnt += 1
      }
      (Mem(base, offset), false) => {
        // Memory address as stack argument
        let _ = func.extend_var_stack(8L, 8L)
        let stack_offset = 8L * (call_ireg_cnt - num_arg_regs).to_int64()
        let vreg = func.new_virtual_reg()
        // Compute effective address: base + offset
        if offset == 0L {
          let inst = builder.build_storei(
            64,
            src=base,
            base=StackPtr,
            offset=stack_offset,
          )
          minsts.push(inst)
        } else {
          let inst1 = builder.build_ibinary_imm(
            Add,
            64,
            dst=vreg,
            src1=base,
            src2=offset,
          )
          let inst2 = builder.build_storei(
            64,
            src=vreg,
            base=StackPtr,
            offset=stack_offset,
          )
          minsts.push(inst1)
          minsts.push(inst2)
        }
        call_ireg_cnt += 1
      }
      arg_op =>
        raise IRTranslateError(
          "CallInst: Unsupported argument operand type: \{arg_op}",
        )
    }
  }
  let call_inst = builder.build_call(callee_name)
  for i = 0; i < call_ireg_cnt && i < num_arg_regs; i = i + 1 {
    call_inst.uses.push(IRegister(AReg(i)))
  }
  for i = 0; i < call_freg_cnt && i < num_arg_fregs; i = i + 1 {
    call_inst.uses.push(FRegister(FAReg(i)))
  }
  minsts.push(call_inst)
  if !(llvm_inst.getType().asTypeEnum() is VoidType(_)) {
    guard func.get_operand_from_llvm_value(llvm_inst) is Some(ret_op) else {
      raise IRTranslateError(
        "CallInst: return value operand not found in value_map",
      )
    }
    match ret_op {
      IRegister(dst) => {
        let inst = builder.build_imove(64, dst~, src=AReg(0))
        minsts.push(inst)
      }
      FRegister(dst) => {
        let inst = builder.build_fmove(64, dst~, src=FAReg(0))
        minsts.push(inst)
      }
      _ => ()
    }
  }
  minsts
}

///|
pub fn translate_llvm_phi_node(
  llvm_inst : @IR.PHINode,
  func : Function,
) -> Array[Instruction] raise MIRError {
  let { incomings, .. } = llvm_inst
  for imcoming in incomings {
    let (value, llvm_bb) = imcoming
    guard func.get_operand_from_llvm_value(value) is Some(value_op) else {
      raise IRTranslateError(
        "PHINode: incoming value operand not found in value_map",
      )
    }
    guard func.get_operand_from_llvm_value(llvm_bb) is Some(bb_op) else {
      raise IRTranslateError(
        "PHINode: incoming basic block operand not found in value_map",
      )
    }
    guard bb_op is Label(bb_label) else {
      raise IRTranslateError(
        "PHINode: incoming basic block operand is not a label",
      )
    }
    let machine_bb = func.bbmap.get(bb_label).unwrap()
    machine_bb.phi_nodes.push((llvm_inst, value_op))
  }
  []
}

///|
pub fn Function::phi_elimination(func : Self) -> Unit raise MIRError {
  func.body.each(bb => bb.phi_elimination())
}

///|
pub fn BasicBlock::phi_elimination(self : Self) -> Unit raise MIRError {
  let func = self.parent
  let data_layout = func.llvm_func.unwrap().getDataLayout()
  let builder = IRBuilder::new(func, self)
  for pair in self.phi_nodes {
    let (llvm_phi_node, value_op) = pair
    guard func.get_operand_from_llvm_value(llvm_phi_node) is Some(dst_op) else {
      raise IRTranslateError(
        "PHINode: destination operand not found in value_map",
      )
    }
    let data_size = data_layout.getTypeAllocSizeInBits(llvm_phi_node.getType())
    match (dst_op, value_op) {
      (IRegister(dst), IRegister(src)) => {
        let inst = builder.build_imove(data_size, dst~, src~)
        self.push_inst_before_terminator(inst)
      }
      (IRegister(dst), Imm(src)) => {
        let inst = builder.build_imove_imm(data_size, dst~, src~)
        self.push_inst_before_terminator(inst)
      }
      (IRegister(dst), Mem(b, o)) => {
        let src = func.new_virtual_reg()
        let load_inst = builder.build_loadi(
          data_size,
          dst=src,
          base=b,
          offset=o,
        )
        let move_inst = builder.build_imove(data_size, dst~, src~)
        self.push_inst_before_terminator(load_inst)
        self.push_inst_before_terminator(move_inst)
      }
      (FRegister(dst), FRegister(src)) => {
        let inst = builder.build_fmove(data_size, dst~, src~)
        self.push_inst_before_terminator(inst)
      }
      phi =>
        raise IRTranslateError(
          "PHINode: Unsupported operand types for phi elimination \{phi}",
        )
    }
  }
}
