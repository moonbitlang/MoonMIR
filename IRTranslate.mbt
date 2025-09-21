///|
traitalias @IR.Value as LLVMValue

//
//traitalias @IR.Instruction as LLVMInstruction

///|
pub suberror IRTranslateError String derive(Show)

/////|
//pub fn Module::from_llvm_module(llvm_mod : @IR.Module) -> Module raise {
//  let functions : Array[Function] = Array::new()
//  for func in llvm_mod.functions.values() {
//    let f = Function::from_llvm_function(func)
//    functions.push(f)
//  }
//  Module::{ functions, }
//}

///|
//pub fn Function::from_llvm_function(func : LLVMFunction) -> Function raise {
//  let value_map = ValueMap::new()
//  let stack_size : Ref[Int] = Ref::new(0)
//  let params : Array[Operand] = Array::new()
//  for arg in func.arguments {
//    if arg.getType().isIEEELikeFPTy() {
//      let op = value_map.bind_llvmvalue_to_vfreg(arg)
//      params.push(op)
//    } else {
//      let op = value_map.bind_llvmvalue_to_vreg(arg)
//      params.push(op)
//    }
//  }
//
//  // Get BasicBlocks labels
//  let name = func.getName().unwrap_or("unnamed")
//  for i, llvm_bb in func.basicBlocks {
//    let label = if llvm_bb.getName() is Some(n) { n } else { "L\{i}" }
//    value_map.map[llvm_bb] = Label(label)
//  }
//  // First create all basic blocks and add them to bbmap
//  let body : Array[BasicBlock] = Array::new()
//  for i, llvm_bb in func.basicBlocks {
//    let label = if llvm_bb.getName() is Some(n) { n } else { "L\{i}" }
//    let bb = BasicBlock::new(label)
//    value_map.bbmap[label] = bb
//    body.push(bb)
//  }
//
//  // Then process instructions for each basic block
//  for i, llvm_bb in func.basicBlocks {
//    let bb = body[i]
//    for inst in llvm_bb.instIter() {
//      let minsts = Instruction::from_llvm_inst(inst, value_map, stack_size) catch {
//        e => {
//          println("Error converting instruction in BB \{bb.label}:")
//          println("  Instruction: \{inst}")
//          raise e
//        }
//      }
//      minsts.each(m => bb.insts.push(m))
//    }
//  }
//
//  // Finally set up predecessors
//  for i, llvm_bb in func.basicBlocks {
//    let bb = body[i]
//    for pred in llvm_bb.preds {
//      guard value_map.get(pred) is Some(Label(bb_label))
//      bb.preds.push(value_map.bbmap[bb_label])
//    }
//  }
//  let stack_size = stack_size.val
//  let f = Function::{ name, params, body, stack_size }
//  f.phi_elimination()
//  if f.stack_size > 0 {
//    f.prologue_epilogue_insertion()
//  }
//  f
//}

///|
fn Instruction::from_llvm_inst(
  inst : &@IR.Instruction,
  bb : BasicBlock,
) -> Array[Instruction] raise IRTranslateError {
  let func = bb.parent
  let mod = inst.getModule()
  let data_layout = mod.getDataLayout()
  let bb = Some(bb)
  match inst.asInstEnum() {
    AllocaInst({ data_ty, .. }) => {
      let data_size = data_layout.getTypeAllocSize(data_ty).to_int64()
      let offset = func.stack_size
      func.stack_size += data_size
      let _ = func.bind_llvm_value_to_mem(inst, offset)
      []
    }
    LoadInst({ vty, ptr, .. }) => {
      guard func.get_operand_from_llvm_value(ptr) is Some(ptr_op) else {
        raise IRTranslateError(
          "LoadInst: pointer operand not found in value map",
        )
      }
      let op = if vty.isIEEELikeFPTy() {
        func.bind_llvm_value_to_vfreg(inst)
      } else {
        func.bind_llvm_value_to_vreg(inst)
      }
      let data_size = data_layout.getTypeAllocSize(vty)
      let opcode = match data_size {
        1 => Loadb
        2 => Loadw
        4 => Loadl
        8 => Loadq
        _ => Load(data_size)
      }
      let minst = Instruction::new(opcode, [op], [ptr_op], bb~)
      [minst]
    }
    StoreInst({ value, ptr, .. }) => {
      let value_op = match value.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard func.get_operand_from_llvm_value(value) is Some(op) else {
            raise IRTranslateError(
              "StoreInst: value operand not found in value map",
            )
          }
          op
        }
        _ => raise IRTranslateError("StoreInst: unsupported value type")
      }
      guard func.get_operand_from_llvm_value(ptr) is Some(ptr_op) else {
        raise IRTranslateError(
          "StoreInst: pointer operand not found in value map",
        )
      }
      let data_ty = value.getType()
      let data_size = data_layout.getTypeAllocSize(data_ty)
      let opcode = match data_size {
        1 => Storeb
        2 => Storew
        4 => Storel
        8 => Storeq
        _ => Store(data_size)
      }
      let minst = Instruction::new(opcode, [], [ptr_op, value_op], bb~)
      [minst]
    }
    BinaryInst({ opcode, lhs, rhs, .. }) => {
      //let opcode = llvm_binary_opcode_to_opcode(opcode)
      let data_ty = lhs.getType()
      let data_size = data_layout.getTypeAllocSize(data_ty)
      let opcode = match (opcode, data_size) {
        (Add, 1) => Addb
        (Add, 2) => Addw
        (Add, 4) => Addl
        (Add, 8) => Addq
        (Add, n) => Add(n)
        (Sub, 1) => Subb
        (Sub, 2) => Subw
        (Sub, 4) => Subl
        (Sub, 8) => Subq
        (Sub, n) => Sub(n)
        (Mul, 1) => Mulb
        (Mul, 2) => Mulw
        (Mul, 4) => Mull
        (Mul, 8) => Mulq
        (Mul, n) => Mul(n)
        (UDiv | SDiv, 1) => Divb
        (UDiv | SDiv, 2) => Divw
        (UDiv | SDiv, 4) => Divl
        (UDiv | SDiv, 8) => Divq
        (UDiv | SDiv, n) => Div(n)
        (URem | SRem, 1) => Remb
        (URem | SRem, 2) => Remw
        (URem | SRem, 4) => Reml
        (URem | SRem, 8) => Remq
        (URem | SRem, n) => Rem(n)
        (FAdd, 4) => FAddS
        (FAdd, 8) => FAddD
        (FSub, 4) => FSubS
        (FSub, 8) => FSubD
        (FMul, 4) => FMulS
        (FMul, 8) => FMulD
        (FDiv, 4) => FDivS
        (FDiv, 8) => FDivD
        // Bitwise operations (size-independent for integers)
        (And, _) => And
        (Or, _) => Or
        (Xor, _) => Xor
        // Shift operations (size-independent for integers)
        (Shl, _) => Shl
        (LShr, _) => LShr
        (AShr, _) => AShr
        _ =>
          raise IRTranslateError(
            "Unsupported BinaryInst opcode {\{opcode}} and data size {\{data_size}}",
          )
      }
      let def_op = if lhs.getType().isIEEELikeFPTy() {
        func.bind_llvm_value_to_vfreg(inst)
      } else {
        func.bind_llvm_value_to_vreg(inst)
      }
      let lhs_op = match lhs.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard func.get_operand_from_llvm_value(lhs) is Some(op) else {
            raise IRTranslateError(
              "BinaryInst: lhs operand not found in value map",
            )
          }
          op
        }
        _ => raise IRTranslateError("BinaryInst: unsupported lhs type")
      }
      let rhs_op = match rhs.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard func.get_operand_from_llvm_value(rhs) is Some(op) else {
            raise IRTranslateError(
              "BinaryInst: rhs operand not found in value map",
            )
          }
          op
        }
        _ => raise IRTranslateError("BinaryInst: unsupported rhs type")
      }
      let minst = Instruction::new(opcode, [def_op], [lhs_op, rhs_op], bb~)
      [minst]
    }
    // TODO: Should be Branch Inst sometimes
    ICmpInst({ predicate, lhs, rhs, .. } as inst) => {
      // If the ICmpInst is only used by a BranchInst,
      // we do not generate a separate instruction for it.
      let inst_users = inst.getUsers().unwrap()
      if inst_users.length() == 1 &&
        inst_users[0].asValueEnum() is BranchInst(_) {
        return []
      }
      let opcode = match predicate {
        EQ => Eq
        NE => Ne
        UGT | SGT => Gt
        UGE | SGE => Ge
        ULT | SLT => Lt
        ULE | SLE => Le
      }
      let def_op = func.bind_llvm_value_to_vreg(inst)
      let lhs_op = match lhs.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        None => {
          guard func.get_operand_from_llvm_value(lhs) is Some(op) else {
            raise IRTranslateError(
              "ICmpInst: lhs operand not found in value map",
            )
          }
          op
        }
        _ => raise IRTranslateError("ICmpInst: unsupported lhs type")
      }
      let rhs_op = match rhs.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        None => {
          guard func.get_operand_from_llvm_value(rhs) is Some(op) else {
            raise IRTranslateError(
              "ICmpInst: rhs operand not found in value map",
            )
          }
          op
        }
        _ => raise IRTranslateError("ICmpInst: unsupported rhs type")
      }
      let minst = Instruction::new(opcode, [def_op], [lhs_op, rhs_op], bb~)
      [minst]
    }
    FCmpInst({ predicate, lhs, rhs, .. }) => {
      let data_ty = lhs.getType()
      let data_size = data_layout.getTypeAllocSize(data_ty)
      let opcode = match (predicate, data_size) {
        (OEQ, 4) => FeqS
        (OEQ, 8) => FeqD
        (ONE, 4) => FneS
        (ONE, 8) => FneD
        (OGT, 4) => FgtS
        (OGT, 8) => FgtD
        (OGE, 4) => FgeS
        (OGE, 8) => FgeD
        (OLT, 4) => FltS
        (OLT, 8) => FltD
        (OLE, 4) => FleS
        (OLE, 8) => FleD
        _ =>
          raise IRTranslateError(
            "Unsupported FCmpInst predicate {\{predicate}} and data size {\{data_size}}",
          )
      }
      let def_op = func.bind_llvm_value_to_vreg(inst)
      let lhs_op = match lhs.tryAsConstantEnum() {
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard func.get_operand_from_llvm_value(lhs) is Some(op) else {
            raise IRTranslateError(
              "FCmpInst: lhs operand not found in value map",
            )
          }
          op
        }
        _ => raise IRTranslateError("FCmpInst: unsupported lhs type")
      }
      let rhs_op = match rhs.tryAsConstantEnum() {
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard func.get_operand_from_llvm_value(rhs) is Some(op) else {
            raise IRTranslateError(
              "FCmpInst: rhs operand not found in value map",
            )
          }
          op
        }
        _ => raise IRTranslateError("FCmpInst: unsupported rhs type")
      }
      let minst = Instruction::new(opcode, [def_op], [lhs_op, rhs_op], bb~)
      [minst]
    }
    BranchInst(
      {
        condition: Some(cond),
        trueBlock: Some(trueBB),
        falseBlock: Some(falseBB),
        ..,
      }
    ) => {
      guard func.get_operand_from_llvm_value(trueBB) is Some(true_label) else {
        raise IRTranslateError(
          "BranchInst: true block operand not found in value map",
        )
      }
      guard func.get_operand_from_llvm_value(falseBB) is Some(false_label) else {
        raise IRTranslateError(
          "BranchInst: false block operand not found in value map",
        )
      }
      let minst = if func.get_operand_from_llvm_value(cond) is Some(cond_op) {
        Instruction::new(
          Bne,
          [],
          [cond_op, Imm(0), true_label, false_label],
          bb~,
        )
      } else {
        // Must Be ICmp
        guard cond.asValueEnum() is ICmpInst({ predicate, lhs, rhs, .. }) else {
          raise IRTranslateError("BranchInst: condition is not ICmpInst")
        }
        let opcode = match predicate {
          EQ => Beq
          NE => Bne
          UGT | SGT => Bgt
          UGE | SGE => Bge
          ULT | SLT => Blt
          ULE | SLE => Ble
        }
        let lhs_op = match lhs.tryAsConstantEnum() {
          Some(ConstantInt(c)) => Imm(c.value)
          None => {
            guard func.get_operand_from_llvm_value(lhs) is Some(op) else {
              raise IRTranslateError(
                "BranchInst: condition lhs operand not found in value map",
              )
            }
            op
          }
          _ => raise IRTranslateError("BranchInst: unsupported lhs type")
        }
        let rhs_op = match rhs.tryAsConstantEnum() {
          Some(ConstantInt(c)) => Imm(c.value)
          None => {
            guard func.get_operand_from_llvm_value(rhs) is Some(op) else {
              raise IRTranslateError(
                "BranchInst: condition rhs operand not found in value map",
              )
            }
            op
          }
          _ => raise IRTranslateError("BranchInst: unsupported rhs type")
        }
        Instruction::new(
          opcode,
          [],
          [lhs_op, rhs_op, true_label, false_label],
          bb~,
        )
      }
      [minst]
    }
    BranchInst({ condition: None, trueBlock: Some(trueBB), .. }) => {
      guard func.get_operand_from_llvm_value(trueBB) is Some(true_label) else {
        raise IRTranslateError(
          "BranchInst: true block operand not found in value map",
        )
      }
      let minst = Instruction::new(Jmp, [], [true_label], bb~)
      [minst]
    }
    BranchInst(b) => {
      println("ERROR: Illegal BranchInst with no condition and no trueBlock")
      println("  BranchInst details: \{b}")
      raise IRTranslateError("Illegal BranchInst: missing required fields")
    }
    SwitchInst(_) => raise IRTranslateError("SwitchInst is not supported yet")
    PHINode({ incomings, .. }) => {
      let uses : Array[Operand] = Array::new()
      for incoming in incomings {
        let (value, bb) = incoming
        let op = match value.tryAsConstantEnum() {
          Some(ConstantInt(c)) => Imm(c.value)
          Some(ConstantFP(f)) => FImm(f.value)
          None =>
            // If the value is not in the map, it might be a forward reference
            // We need to allocate a register for it now
            match func.get_operand_from_llvm_value(value) {
              Some(op) => op
              None =>
                // This is a forward reference, allocate a register for it
                if value.getType().isIEEELikeFPTy() {
                  func.bind_llvm_value_to_vfreg(value)
                } else {
                  func.bind_llvm_value_to_vreg(value)
                }
            }
          _ =>
            raise IRTranslateError("PHINode: unsupported incoming value type")
        }
        uses.push(op)
        uses.push(func.get_operand_from_llvm_value(bb).unwrap()) // Must be Label
      }
      let def_op = if inst.getType().isIEEELikeFPTy() {
        func.bind_llvm_value_to_vfreg(inst)
      } else {
        func.bind_llvm_value_to_vreg(inst)
      }
      let minst = Instruction::new(PHI, [def_op], uses, bb~)
      func.phi_insts.push(minst)
      [minst]
    }
    CastInst({ to_ty, from_val, opcode: cast_op, .. }) => {
      let from_ty = from_val.getType()
      guard func.get_operand_from_llvm_value(from_val) is Some(from_op) else {
        raise IRTranslateError(
          "CastInst: from_val operand not found in value map",
        )
      }
      //let to_ty = to_ty.asTypeEnum()
      let opcode = match cast_op {
        ZExt => ZExt
        SExt => SExt
        Trunc => Trunc
        FPExt => FPExt
        FPTrunc => FPTrunc
        IntToPtr | PtrToInt | BitCast => BitCast
        FPToUI =>
          match (from_ty.tryAsFPTypeEnum(), to_ty.tryAsIntTypeEnum()) {
            (Some(FloatType(_)), Some(Int1Type(_))) => FPToUI(32, 1)
            (Some(FloatType(_)), Some(Int8Type(_))) => FPToUI(32, 8)
            (Some(FloatType(_)), Some(Int16Type(_))) => FPToUI(32, 16)
            (Some(FloatType(_)), Some(Int32Type(_))) => FPToUI(32, 32)
            (Some(FloatType(_)), Some(Int64Type(_))) => FPToUI(32, 64)
            (Some(DoubleType(_)), Some(Int1Type(_))) => FPToUI(64, 1)
            (Some(DoubleType(_)), Some(Int8Type(_))) => FPToUI(64, 8)
            (Some(DoubleType(_)), Some(Int16Type(_))) => FPToUI(64, 16)
            (Some(DoubleType(_)), Some(Int32Type(_))) => FPToUI(64, 32)
            (Some(DoubleType(_)), Some(Int64Type(_))) => FPToUI(64, 64)
            _ =>
              raise IRTranslateError(
                "Unsupported CastInst FPToUI from {\{from_ty}} to {\{to_ty}}",
              )
          }
        UIToFP =>
          match (from_ty.tryAsIntTypeEnum(), to_ty.tryAsFPTypeEnum()) {
            (Some(Int1Type(_)), Some(FloatType(_))) => UIToFP(1, 32)
            (Some(Int8Type(_)), Some(FloatType(_))) => UIToFP(8, 32)
            (Some(Int16Type(_)), Some(FloatType(_))) => UIToFP(16, 32)
            (Some(Int32Type(_)), Some(FloatType(_))) => UIToFP(32, 32)
            (Some(Int64Type(_)), Some(FloatType(_))) => UIToFP(64, 32)
            (Some(Int1Type(_)), Some(DoubleType(_))) => UIToFP(1, 64)
            (Some(Int8Type(_)), Some(DoubleType(_))) => UIToFP(8, 64)
            (Some(Int16Type(_)), Some(DoubleType(_))) => UIToFP(16, 64)
            (Some(Int32Type(_)), Some(DoubleType(_))) => UIToFP(32, 64)
            (Some(Int64Type(_)), Some(DoubleType(_))) => UIToFP(64, 64)
            _ =>
              raise IRTranslateError(
                "Unsupported CastInst UIToFP from {\{from_ty}} to {\{to_ty}}",
              )
          }
        FPToSI =>
          match (from_ty.tryAsFPTypeEnum(), to_ty.tryAsIntTypeEnum()) {
            (Some(FloatType(_)), Some(Int1Type(_))) => FPToSI(32, 1)
            (Some(FloatType(_)), Some(Int8Type(_))) => FPToSI(32, 8)
            (Some(FloatType(_)), Some(Int16Type(_))) => FPToSI(32, 16)
            (Some(FloatType(_)), Some(Int32Type(_))) => FPToSI(32, 32)
            (Some(FloatType(_)), Some(Int64Type(_))) => FPToSI(32, 64)
            (Some(DoubleType(_)), Some(Int1Type(_))) => FPToSI(64, 1)
            (Some(DoubleType(_)), Some(Int8Type(_))) => FPToSI(64, 8)
            (Some(DoubleType(_)), Some(Int16Type(_))) => FPToSI(64, 16)
            (Some(DoubleType(_)), Some(Int32Type(_))) => FPToSI(64, 32)
            (Some(DoubleType(_)), Some(Int64Type(_))) => FPToSI(64, 64)
            _ =>
              raise IRTranslateError(
                "Unsupported CastInst FPToSI from {\{from_ty}} to {\{to_ty}}",
              )
          }
        SIToFP =>
          match (from_ty.tryAsIntTypeEnum(), to_ty.tryAsFPTypeEnum()) {
            (Some(Int1Type(_)), Some(FloatType(_))) => SIToFP(1, 32)
            (Some(Int8Type(_)), Some(FloatType(_))) => SIToFP(8, 32)
            (Some(Int16Type(_)), Some(FloatType(_))) => SIToFP(16, 32)
            (Some(Int32Type(_)), Some(FloatType(_))) => SIToFP(32, 32)
            (Some(Int64Type(_)), Some(FloatType(_))) => SIToFP(64, 32)
            (Some(Int1Type(_)), Some(DoubleType(_))) => SIToFP(1, 64)
            (Some(Int8Type(_)), Some(DoubleType(_))) => SIToFP(8, 64)
            (Some(Int16Type(_)), Some(DoubleType(_))) => SIToFP(16, 64)
            (Some(Int32Type(_)), Some(DoubleType(_))) => SIToFP(32, 64)
            (Some(Int64Type(_)), Some(DoubleType(_))) => SIToFP(64, 64)
            _ =>
              raise IRTranslateError(
                "Unsupported CastInst SIToFP from {\{from_ty}} to {\{to_ty}}",
              )
          }
      }
      let def_op = if to_ty.isIEEELikeFPTy() {
        func.bind_llvm_value_to_vfreg(inst)
      } else {
        func.bind_llvm_value_to_vreg(inst)
      }
      let minst = Instruction::new(opcode, [def_op], [from_op], bb~)
      [minst]
    }
    GetElementPtrInst({ ptr, indices, pointeeType, .. }) => {
      guard func.get_operand_from_llvm_value(ptr) is Some(ptr_op) else {
        raise IRTranslateError(
          "GetElementPtrInst: pointer operand not found in value map",
        )
      }
      let insts : Array[Instruction] = Array::new()
      let indices = indices.map(i => i.asValueEnum())

      // Current pointer operand, may be updated as we process indices
      let current_ptr = ptr_op
      loop (pointeeType.asTypeEnum(), indices[:], current_ptr) {
        // Handle cases based on the current type and remaining indices
        (ArrayType(arrTy), [ConstantInt(c), .. rest], ptr) => {
          let elem_ty = arrTy.getElementType()
          let elem_size = data_layout.getTypeAllocSize(elem_ty).to_int64()
          let offset = elem_size * c.getValueAsInt64()
          if offset != 0 {
            let offset_op = Imm(offset)
            let new_ptr = func.add_vreg()
            let minst = Instruction::new(Addq, [new_ptr], [ptr, offset_op], bb~)
            insts.push(minst)
            continue (elem_ty.asTypeEnum(), rest, new_ptr)
          } else {
            // offset is 0, just continue with same pointer
            continue (elem_ty.asTypeEnum(), rest, ptr)
          }
        }
        (ArrayType(arrTy), [idx, .. rest], ptr) => {
          let elem_ty = arrTy.getElementType()
          let elem_size = data_layout.getTypeAllocSize(elem_ty).to_int64()
          let idx_op = func
            .get_operand_from_llvm_value(idx.asValueClass())
            .unwrap()
          if elem_size == 1 {
            // For byte arrays, no need to scale
            let new_ptr = func.add_vreg()
            let minst = Instruction::new(Addq, [new_ptr], [ptr, idx_op], bb~)
            insts.push(minst)
            continue (elem_ty.asTypeEnum(), rest, new_ptr)
          } else {
            // Scale the index
            let offset_op = func.add_vreg()
            let scale_inst = Instruction::new(
              Mulq,
              [offset_op],
              [idx_op, Imm(elem_size)],
              bb~,
            )
            insts.push(scale_inst)
            let new_ptr = func.add_vreg()
            let add_inst = Instruction::new(
              Addq,
              [new_ptr],
              [ptr, offset_op],
              bb~,
            )
            insts.push(add_inst)
            continue (elem_ty.asTypeEnum(), rest, new_ptr)
          }
        }
        (StructType(structTy), [ConstantInt(c), .. rest], ptr) => {
          let i = c.getValueAsInt64().to_int()
          let offset = data_layout.getStructTypeOffset(structTy, i).to_int64()
          if offset != 0 {
            let offset_op = Imm(offset)
            let new_ptr = func.add_vreg()
            let minst = Instruction::new(Addq, [new_ptr], [ptr, offset_op], bb~)
            insts.push(minst)
            let elem_ty = structTy.elements[i]
            continue (elem_ty.asTypeEnum(), rest, new_ptr)
          } else {
            // offset is 0, just continue with same pointer
            let elem_ty = structTy.elements[i]
            continue (elem_ty.asTypeEnum(), rest, ptr)
          }
        }
        (StructType(_), [_, ..], _) =>
          raise IRTranslateError(
            "GetElementPtrInst with non-constant struct index is impossible",
          )
        (
          _,
          [
            // Handle simple pointer arithmetic for primitive types
            ConstantInt(c),
          ],
          ptr,
        ) => {
          let offset = data_layout.getTypeAllocSize(pointeeType).to_int64() *
            c.getValueAsInt64()
          if offset != 0 {
            let offset_op = Imm(offset)
            let final_ptr = func.bind_llvm_value_to_vreg(inst)
            let minst = Instruction::new(
              Addq,
              [final_ptr],
              [ptr, offset_op],
              bb~,
            )
            insts.push(minst)
          } else {
            // offset is 0, just bind the pointer to the result
            func.value_map[inst] = ptr
          }
          // We're done
          break
        }
        (_, [idx], ptr) => {
          let idx_op = func
            .get_operand_from_llvm_value(idx.asValueClass())
            .unwrap()
          let elem_size = data_layout.getTypeAllocSize(pointeeType).to_int64()
          if elem_size == 1 {
            // For byte pointers, no need to scale
            let final_ptr = func.bind_llvm_value_to_vreg(inst)
            let minst = Instruction::new(Addq, [final_ptr], [ptr, idx_op], bb~)
            insts.push(minst)
          } else {
            // Scale the index
            let offset_op = func.add_vreg()
            let scale_inst = Instruction::new(
              Mulq,
              [offset_op],
              [idx_op, Imm(elem_size)],
              bb~,
            )
            insts.push(scale_inst)
            let final_ptr = func.bind_llvm_value_to_vreg(inst)
            let add_inst = Instruction::new(
              Addq,
              [final_ptr],
              [ptr, offset_op],
              bb~,
            )
            insts.push(add_inst)
          }
          // We're done
          break
        }
        // Base case: no more indices
        (_, [], ptr) => {
          // Just bind the final pointer
          func.value_map[inst] = ptr
          break
        }
        _ =>
          raise IRTranslateError(
            "GetElementPtrInst with unsupported type/index combination",
          )
      }
      insts
    }
    SelectInst({ condition, trueValue, falseValue, .. }) => {
      let cond_op = match condition.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        None => {
          guard func.get_operand_from_llvm_value(condition) is Some(op) else {
            raise IRTranslateError(
              "SelectInst: condition operand not found in value map",
            )
          }
          op
        }
        _ => raise IRTranslateError("SelectInst: unsupported condition type")
      }
      let true_op = match trueValue.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard func.get_operand_from_llvm_value(trueValue) is Some(op) else {
            raise IRTranslateError(
              "SelectInst: trueValue operand not found in value map",
            )
          }
          op
        }
        _ => raise IRTranslateError("SelectInst: unsupported trueValue type")
      }
      let false_op = match falseValue.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard func.get_operand_from_llvm_value(falseValue) is Some(op) else {
            raise IRTranslateError(
              "SelectInst: falseValue operand not found in value map",
            )
          }
          op
        }
        _ => raise IRTranslateError("SelectInst: unsupported falseValue type")
      }
      let def_op = if trueValue.getType().isIEEELikeFPTy() {
        func.bind_llvm_value_to_vfreg(inst)
      } else {
        func.bind_llvm_value_to_vreg(inst)
      }
      let minst = Instruction::new(
        Select,
        [def_op],
        [cond_op, true_op, false_op],
        bb~,
      )
      [minst]
    }
    ReturnInst({ retVal, .. }) =>
      if retVal is Some(retVal) {
        let ret_op = match retVal.tryAsConstantEnum() {
          Some(ConstantInt(c)) => Imm(c.value)
          Some(ConstantFP(f)) => FImm(f.value)
          None => {
            guard func.get_operand_from_llvm_value(retVal) is Some(op) else {
              raise IRTranslateError(
                "ReturnInst: return value operand not found in value map",
              )
            }
            op
          }
          _ =>
            raise IRTranslateError("ReturnInst: unsupported return value type")
        }
        let ret_inst = Instruction::new(Ret, [], [ret_op], bb~)
        func.terminal_basic_blocks.push(bb.unwrap())
        [ret_inst]
      } else {
        let minst = Instruction::new(Ret, [], [], bb~)
        [minst]
      }
    CallInst({ callee, args, .. }) => {
      let { num_arg_regs, num_arg_fregs, .. } = func.getArchConfig()
      let insts : Array[Instruction] = Array::new()
      let mut vreg_arg_cnt = 0
      let mut vfreg_arg_cnt = 0
      let callee_name = callee.getName().unwrap()
      let uses : Array[Operand] = Array::new()
      uses.push(Label(callee_name))
      for arg in args {
        match arg.asValueEnum() {
          ConstantInt(c) if vreg_arg_cnt < num_arg_regs => {
            let vreg = func.add_vreg()
            let opcode = match c.getType().tryAsIntTypeEnum() {
              Some(Int1Type(_)) | Some(Int8Type(_)) => Movb
              Some(Int16Type(_)) => Movw
              Some(Int32Type(_)) => Movl
              Some(Int64Type(_)) => Movq
              _ =>
                raise IRTranslateError(
                  "CallInst: unsupported ConstantInt type for argument",
                )
            }
            let loadi = Instruction::new(
              opcode,
              [vreg],
              [Imm(c.getValueAsInt64())],
              bb~,
            )
            insts.push(loadi)
            uses.push(vreg)
            vreg_arg_cnt += 1
          }
          // if vreg_arg_cnt >= num_arg_regs, we pass the argument on stack
          ConstantInt(c) => {
            let offset = func.stack_size
            let storei = Instruction::new(
              Storeq,
              [],
              [Mem(StackPtr, offset), Imm(c.getValueAsInt64())],
              bb~,
            )
            insts.push(storei)
            uses.push(Mem(StackPtr, offset))
            func.stack_size += 8 // Align to 8 bytes
          }
          ConstantFP(f) if vfreg_arg_cnt < num_arg_fregs => {
            let vfreg = func.add_vfreg()
            let opcode = match f.getType().tryAsFPTypeEnum() {
              Some(FloatType(_)) => FMovS
              Some(DoubleType(_)) => FMovD
              _ =>
                raise IRTranslateError(
                  "CallInst: unsupported ConstantFP type for argument",
                )
            }
            let loadfi = Instruction::new(opcode, [vfreg], [FImm(f.value)], bb~)
            insts.push(loadfi)
            uses.push(vfreg)
            vfreg_arg_cnt += 1
          }
          ConstantFP(f) => {
            let offset = func.stack_size
            let storei = Instruction::new(
              Storeq,
              [],
              [Mem(StackPtr, offset), FImm(f.value)],
              bb~,
            )
            insts.push(storei)
            uses.push(Mem(StackPtr, offset))
            func.stack_size += 8 // Align to 8 bytes
          }
          _ => {
            guard func.get_operand_from_llvm_value(arg) is Some(op) else {
              raise IRTranslateError(
                "CallInst: argument operand not found in value map",
              )
            }
            match op {
              VReg(_) if vreg_arg_cnt < num_arg_regs => {
                uses.push(op)
                vreg_arg_cnt += 1
              }
              VReg(_) => {
                let offset = func.stack_size
                let storei = Instruction::new(
                  Storeq,
                  [],
                  [Mem(StackPtr, offset), op],
                  bb~,
                )
                insts.push(storei)
                uses.push(Mem(StackPtr, offset))
                func.stack_size += 8 // Align to 8 bytes
              }
              VFReg(_) if vfreg_arg_cnt < num_arg_fregs => {
                uses.push(op)
                vfreg_arg_cnt += 1
              }
              VFReg(_) => {
                let offset = func.stack_size
                let storei = Instruction::new(
                  Storeq,
                  [],
                  [Mem(StackPtr, offset), op],
                  bb~,
                )
                insts.push(storei)
                uses.push(Mem(StackPtr, offset))
                func.stack_size += 8 // Align to 8 bytes
              }
              Mem(r, offset) if !arg.getType().isIEEELikeFPTy() &&
                vreg_arg_cnt < num_arg_regs => {
                let vreg = func.add_vreg()
                let loadi = Instruction::new(
                  Loadq,
                  [vreg],
                  [Mem(r, offset)],
                  bb~,
                )
                insts.push(loadi)
                uses.push(vreg)
                vreg_arg_cnt += 1
              }
              Mem(r, offset) if arg.getType().isIEEELikeFPTy() &&
                vfreg_arg_cnt < num_arg_fregs => {
                let vfreg = func.add_vfreg()
                let loadi = Instruction::new(
                  FMovD,
                  [vfreg],
                  [Mem(r, offset)],
                  bb~,
                )
                insts.push(loadi)
                uses.push(vfreg)
                vfreg_arg_cnt += 1
              }
              Mem(r, offset) if !arg.getType().isIEEELikeFPTy() => {
                let stack_offset = func.stack_size
                let storei = Instruction::new(
                  Storeq,
                  [],
                  [Mem(StackPtr, stack_offset), Mem(r, offset)],
                  bb~,
                )
                insts.push(storei)
                uses.push(Mem(StackPtr, stack_offset))
                func.stack_size += 8 // Align to 8 bytes
              }
              Mem(r, offset) => {
                let stack_offset = func.stack_size
                let storei = Instruction::new(
                  Storeq,
                  [],
                  [Mem(StackPtr, stack_offset), Mem(r, offset)],
                  bb~,
                )
                insts.push(storei)
                uses.push(Mem(StackPtr, stack_offset))
                func.stack_size += 8 // Align to 8 bytes
              }
              _ =>
                raise IRTranslateError(
                  "CallInst: unsupported argument operand type",
                )
            }
          }
        }
      }
      let defs : Array[Operand] = Array::new()
      if !(inst.getType().asTypeEnum() is VoidType(_)) {
        let ret_op = if inst.getType().isIEEELikeFPTy() {
          func.bind_llvm_value_to_vfreg(inst)
        } else {
          func.bind_llvm_value_to_vreg(inst)
        }
        defs.push(ret_op)
      }
      let call_inst = Instruction::new(Call, defs, uses, bb~)
      insts.push(call_inst)
      insts
    }
    ExtractValueInst(_) =>
      raise IRTranslateError("ExtractValueInst is not supported yet")
    InsertValueInst(_) =>
      raise IRTranslateError("InsertValueInst is not supported yet")
  }
}
