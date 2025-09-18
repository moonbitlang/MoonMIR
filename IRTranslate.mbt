///|
traitalias @IR.Value as LLVMValue

//
//traitalias @IR.Instruction as LLVMInstruction

///|
typealias @IR.Function as LLVMFunction

///|
pub suberror IRTranslateError String derive(Show)

///|
priv struct ValueMap {
  map : Map[&@IR.Value, Operand]
  bbmap : Map[String, BasicBlock] // Map from label to BasicBlock
  mut vreg_cnt : Int
  mut vfreg_cnt : Int
}

///|
fn ValueMap::new() -> ValueMap {
  ValueMap::{ map: Map::new(), bbmap: Map::new(), vreg_cnt: 0, vfreg_cnt: 0 }
}

///|
fn ValueMap::add_vreg(self : Self) -> Operand {
  let i = self.vreg_cnt
  let op = VReg(i)
  self.vreg_cnt += 1
  op
}

///|
fn ValueMap::bind_llvmvalue_to_vreg(self : Self, val : &LLVMValue) -> Operand {
  let i = self.vreg_cnt
  let op = VReg(i)
  self.map[val] = op
  self.vreg_cnt += 1
  op
}

///|
fn ValueMap::bind_llvmvalue_to_vfreg(self : Self, val : &LLVMValue) -> Operand {
  let i = self.vfreg_cnt
  let op = VFReg(i)
  self.map[val] = op
  self.vfreg_cnt += 1
  op
}

///|
fn ValueMap::bind_llvmvalue_to_mem(
  self : Self,
  val : &LLVMValue,
  offset : Int,
) -> Operand {
  let op = Mem(StackTop, offset)
  self.map[val] = op
  op
}

///|
fn ValueMap::get(self : Self, val : &LLVMValue) -> Operand? {
  self.map.get(val)
}

///|
pub fn Module::from_llvm_module(llvm_mod : @IR.Module) -> Module raise {
  let functions : Array[Function] = Array::new()
  for func in llvm_mod.functions.values() {
    let f = Function::from_llvm_function(func)
    functions.push(f)
  }
  Module::{ functions, }
}

///|
pub fn Function::from_llvm_function(func : LLVMFunction) -> Function raise {
  let value_map = ValueMap::new()
  let stack_size : Ref[Int] = Ref::new(0)
  let params : Array[Operand] = Array::new()
  for arg in func.arguments {
    if arg.getType().isIEEELikeFPTy() {
      let op = value_map.bind_llvmvalue_to_vfreg(arg)
      params.push(op)
    } else {
      let op = value_map.bind_llvmvalue_to_vreg(arg)
      params.push(op)
    }
  }

  // Get BasicBlocks labels
  let name = func.getName().unwrap_or("unnamed")
  for i, llvm_bb in func.basicBlocks {
    let label = if llvm_bb.getName() is Some(n) { n } else { "L\{i}" }
    value_map.map[llvm_bb] = Label(label)
  }
  let body : Array[BasicBlock] = Array::new()
  for i, llvm_bb in func.basicBlocks {
    let label = if llvm_bb.getName() is Some(n) { n } else { "L\{i}" }
    let bb = BasicBlock::from_llvm_bb(llvm_bb, value_map, stack_size, label)
    value_map.bbmap[label] = bb
    body.push(bb)
  }
  let stack_size = stack_size.val
  let f = Function::{ name, params, body, stack_size }
  f
}

///|
fn BasicBlock::from_llvm_bb(
  llvm_bb : @IR.BasicBlock,
  value_map : ValueMap,
  stack_size : Ref[Int],
  label : String,
) -> BasicBlock raise {
  let bb = BasicBlock::new(label)
  for inst in llvm_bb.instIter() {
    let minsts = Instruction::from_llvm_inst(inst, value_map, stack_size)
    minsts.each(m => bb.insts.push(m))
  }
  for pred in llvm_bb.preds {
    guard value_map.get(pred) is Some(Label(bb_label))
    bb.preds.push(value_map.bbmap[bb_label])
  }
  bb
}

///|
fn Instruction::from_llvm_inst(
  inst : &@IR.Instruction,
  value_map : ValueMap,
  stack_size : Ref[Int],
) -> Array[Instruction] raise {
  //let ctx = inst.getContext()
  let mod = inst.getModule()
  let data_layout = mod.getDataLayout()
  match inst.asInstEnum() {
    AllocaInst({ data_ty, .. }) => {
      let data_size = data_layout.getTypeAllocSize(data_ty)
      let offset = stack_size.val
      stack_size.val += data_size
      let _ = value_map.bind_llvmvalue_to_mem(inst, offset)
      []
    }
    LoadInst({ vty, ptr, .. }) => {
      guard value_map.get(ptr) is Some(ptr_op) else {
        raise IRTranslateError(
          "LoadInst: pointer operand not found in value map",
        )
      }
      let op = if vty.isIEEELikeFPTy() {
        value_map.bind_llvmvalue_to_vfreg(inst)
      } else {
        value_map.bind_llvmvalue_to_vreg(inst)
      }
      let data_size = data_layout.getTypeAllocSize(vty)
      let opcode = match data_size {
        1 => Loadb
        2 => Loadw
        4 => Loadl
        8 => Loadq
        _ => Load(data_size)
      }
      let minst = Instruction::{ opcode, defs: [op], uses: [ptr_op] }
      [minst]
    }
    StoreInst({ value, ptr, .. }) => {
      let value_op = match value.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard value_map.get(value) is Some(op) else {
            raise IRTranslateError(
              "StoreInst: value operand not found in value map",
            )
          }
          op
        }
        _ =>
          raise IRTranslateError("StoreInst: unsupported value type")
      }
      guard value_map.get(ptr) is Some(ptr_op) else {
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
      let minst = Instruction::{ opcode, defs: [], uses: [ptr_op, value_op] }
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
        value_map.bind_llvmvalue_to_vfreg(inst)
      } else {
        value_map.bind_llvmvalue_to_vreg(inst)
      }
      let lhs_op = match lhs.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard value_map.get(lhs) is Some(op) else {
            raise IRTranslateError("BinaryInst: lhs operand not found in value map")
          }
          op
        }
        _ => raise IRTranslateError("BinaryInst: unsupported lhs type")
      }
      let rhs_op = match rhs.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard value_map.get(rhs) is Some(op) else {
            raise IRTranslateError("BinaryInst: rhs operand not found in value map")
          }
          op
        }
        _ => raise IRTranslateError("BinaryInst: unsupported rhs type")
      }
      let minst = Instruction::{
        opcode,
        defs: [def_op],
        uses: [lhs_op, rhs_op],
      }
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
      let def_op = value_map.bind_llvmvalue_to_vreg(inst)
      let lhs_op = match lhs.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        None => {
          guard value_map.get(lhs) is Some(op) else {
            raise IRTranslateError("ICmpInst: lhs operand not found in value map")
          }
          op
        }
        _ => raise IRTranslateError("ICmpInst: unsupported lhs type")
      }
      let rhs_op = match rhs.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        None => {
          guard value_map.get(rhs) is Some(op) else {
            raise IRTranslateError("ICmpInst: rhs operand not found in value map")
          }
          op
        }
        _ => raise IRTranslateError("ICmpInst: unsupported rhs type")
      }
      let minst = Instruction::{
        opcode,
        defs: [def_op],
        uses: [lhs_op, rhs_op],
      }
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
      let def_op = value_map.bind_llvmvalue_to_vreg(inst)
      let lhs_op = match lhs.tryAsConstantEnum() {
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard value_map.get(lhs) is Some(op) else {
            raise IRTranslateError("FCmpInst: lhs operand not found in value map")
          }
          op
        }
        _ => raise IRTranslateError("FCmpInst: unsupported lhs type")
      }
      let rhs_op = match rhs.tryAsConstantEnum() {
        Some(ConstantFP(f)) => FImm(f.value)
        None => {
          guard value_map.get(rhs) is Some(op) else {
            raise IRTranslateError("FCmpInst: rhs operand not found in value map")
          }
          op
        }
        _ => raise IRTranslateError("FCmpInst: unsupported rhs type")
      }
      let minst = Instruction::{
        opcode,
        defs: [def_op],
        uses: [lhs_op, rhs_op],
      }
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
      guard value_map.get(trueBB) is Some(true_label) else {
        raise IRTranslateError(
          "BranchInst: true block operand not found in value map",
        )
      }
      guard value_map.get(falseBB) is Some(false_label) else {
        raise IRTranslateError(
          "BranchInst: false block operand not found in value map",
        )
      }
      let minst = if value_map.get(cond) is Some(cond_op) {
        Instruction::{
          opcode: Bne,
          defs: [],
          uses: [cond_op, Imm(0), true_label, false_label],
        }
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
        guard value_map.get(lhs) is Some(lhs_op) else {
          raise IRTranslateError(
            "BranchInst: condition lhs operand not found in value map",
          )
        }
        guard value_map.get(rhs) is Some(rhs_op) else {
          raise IRTranslateError(
            "BranchInst: condition rhs operand not found in value map",
          )
        }
        Instruction::{
          opcode,
          defs: [],
          uses: [lhs_op, rhs_op, true_label, false_label],
        }
      }
      [minst]
    }
    BranchInst({ condition: None, trueBlock: Some(trueBB), .. }) => {
      guard value_map.get(trueBB) is Some(true_label) else {
        raise IRTranslateError(
          "BranchInst: true block operand not found in value map",
        )
      }
      let minst = Instruction::{ opcode: Jmp, defs: [], uses: [true_label] }
      [minst]
    }
    BranchInst(b) => {
      println("Illegal BranchInst: {\{b}}")
      panic()
    }
    SwitchInst(_) => {
      println("Warning: SwitchInst is not supported yet.")
      panic()
    }
    PHINode({ incomings, .. }) => {
      let uses : Array[Operand] = Array::new()
      for incoming in incomings {
        let (value, bb) = incoming
        let op = match value.tryAsConstantEnum() {
          Some(ConstantInt(c)) => Imm(c.value)
          Some(ConstantFP(f)) => FImm(f.value)
          None => {
            guard value_map.get(value) is Some(op) else {
              raise IRTranslateError(
                "PHINode: incoming value operand not found in value map",
              )
            }
            op
          }
          _ =>
            raise IRTranslateError("PHINode: unsupported incoming value type")
        }
        uses.push(op)
        uses.push(value_map.get(bb).unwrap()) // Must be Label
      }
      let def_op = if inst.getType().isIEEELikeFPTy() {
        value_map.bind_llvmvalue_to_vfreg(inst)
      } else {
        value_map.bind_llvmvalue_to_vreg(inst)
      }
      let minst = Instruction::{ opcode: PHI, defs: [def_op], uses }
      [minst]
    }
    CastInst({ to_ty, from_val, opcode: cast_op, .. }) => {
      let from_ty = from_val.getType()
      guard value_map.get(from_val) is Some(from_op) else {
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
        value_map.bind_llvmvalue_to_vfreg(inst)
      } else {
        value_map.bind_llvmvalue_to_vreg(inst)
      }
      let minst = Instruction::{ opcode, defs: [def_op], uses: [from_op] }
      [minst]
    }
    GetElementPtrInst({ ptr, indices, pointeeType, .. }) => {
      guard value_map.get(ptr) is Some(ptr_op) else {
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
            let new_ptr = value_map.add_vreg()
            let minst = Instruction::{
              opcode: Addq,
              defs: [new_ptr],
              uses: [ptr, offset_op],
            }
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
          let idx_op = value_map.get(idx.asValueClass()).unwrap()
          if elem_size == 1 {
            // For byte arrays, no need to scale
            let new_ptr = value_map.add_vreg()
            let minst = Instruction::{
              opcode: Addq,
              defs: [new_ptr],
              uses: [ptr, idx_op],
            }
            insts.push(minst)
            continue (elem_ty.asTypeEnum(), rest, new_ptr)
          } else {
            // Scale the index
            let offset_op = value_map.add_vreg()
            let scale_inst = Instruction::{
              opcode: Mulq,
              defs: [offset_op],
              uses: [idx_op, Imm(elem_size)],
            }
            insts.push(scale_inst)
            let new_ptr = value_map.add_vreg()
            let add_inst = Instruction::{
              opcode: Addq,
              defs: [new_ptr],
              uses: [ptr, offset_op],
            }
            insts.push(add_inst)
            continue (elem_ty.asTypeEnum(), rest, new_ptr)
          }
        }
        (StructType(structTy), [ConstantInt(c), .. rest], ptr) => {
          let i = c.getValueAsInt64().to_int()
          let offset = data_layout.getStructTypeOffset(structTy, i).to_int64()
          if offset != 0 {
            let offset_op = Imm(offset)
            let new_ptr = value_map.add_vreg()
            let minst = Instruction::{
              opcode: Addq,
              defs: [new_ptr],
              uses: [ptr, offset_op],
            }
            insts.push(minst)
            let elem_ty = structTy.elements[i]
            continue (elem_ty.asTypeEnum(), rest, new_ptr)
          } else {
            // offset is 0, just continue with same pointer
            let elem_ty = structTy.elements[i]
            continue (elem_ty.asTypeEnum(), rest, ptr)
          }
        }
        (StructType(_), [_, ..], _) => {
          println(
            "Warning: GetElementPtrInst with non-constant struct index is impossible.",
          )
          panic()
        }
        // Handle simple pointer arithmetic for primitive types
        (_, [ConstantInt(c)], ptr) => {
          let offset = data_layout.getTypeAllocSize(pointeeType).to_int64() *
            c.getValueAsInt64()
          if offset != 0 {
            let offset_op = Imm(offset)
            let final_ptr = value_map.bind_llvmvalue_to_vreg(inst)
            let minst = Instruction::{
              opcode: Addq,
              defs: [final_ptr],
              uses: [ptr, offset_op],
            }
            insts.push(minst)
          } else {
            // offset is 0, just bind the pointer to the result
            value_map.map[inst] = ptr
          }
          // We're done
          break
        }
        (_, [idx], ptr) => {
          let idx_op = value_map.get(idx.asValueClass()).unwrap()
          let elem_size = data_layout.getTypeAllocSize(pointeeType).to_int64()
          if elem_size == 1 {
            // For byte pointers, no need to scale
            let final_ptr = value_map.bind_llvmvalue_to_vreg(inst)
            let minst = Instruction::{
              opcode: Addq,
              defs: [final_ptr],
              uses: [ptr, idx_op],
            }
            insts.push(minst)
          } else {
            // Scale the index
            let offset_op = value_map.add_vreg()
            let scale_inst = Instruction::{
              opcode: Mulq,
              defs: [offset_op],
              uses: [idx_op, Imm(elem_size)],
            }
            insts.push(scale_inst)
            let final_ptr = value_map.bind_llvmvalue_to_vreg(inst)
            let add_inst = Instruction::{
              opcode: Addq,
              defs: [final_ptr],
              uses: [ptr, offset_op],
            }
            insts.push(add_inst)
          }
          // We're done
          break
        }
        // Base case: no more indices
        (_, [], ptr) => {
          // Just bind the final pointer
          value_map.map[inst] = ptr
          break
        }
        _ => {
          println(
            "Warning: GetElementPtrInst with unsupported type/index combination.",
          )
          panic()
        }
      }
      insts
    }
    SelectInst({ condition, trueValue, falseValue, .. }) => {
      let cond_op = match condition.tryAsConstantEnum() {
        Some(ConstantInt(c)) => Imm(c.value)
        None => {
          guard value_map.get(condition) is Some(op) else {
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
          guard value_map.get(trueValue) is Some(op) else {
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
          guard value_map.get(falseValue) is Some(op) else {
            raise IRTranslateError(
              "SelectInst: falseValue operand not found in value map",
            )
          }
          op
        }
        _ => raise IRTranslateError("SelectInst: unsupported falseValue type")
      }
      let def_op = if trueValue.getType().isIEEELikeFPTy() {
        value_map.bind_llvmvalue_to_vfreg(inst)
      } else {
        value_map.bind_llvmvalue_to_vreg(inst)
      }
      let minst = Instruction::{
        opcode: Select,
        defs: [def_op],
        uses: [cond_op, true_op, false_op],
      }
      [minst]
    }
    ReturnInst({ retVal, .. }) =>
      if retVal is Some(retVal) {
        let ret_op = match retVal.tryAsConstantEnum() {
          Some(ConstantInt(c)) => Imm(c.value)
          Some(ConstantFP(f)) => FImm(f.value)
          None => {
            guard value_map.get(retVal) is Some(op) else {
              raise IRTranslateError(
                "ReturnInst: return value operand not found in value map",
              )
            }
            op
          }
          _ =>
            raise IRTranslateError("ReturnInst: unsupported return value type")
        }
        let ret_inst = Instruction::{ opcode: Ret, defs: [], uses: [ret_op] }
        [ret_inst]
      } else {
        let minst = Instruction::{ opcode: Ret, defs: [], uses: [] }
        [minst]
      }
    CallInst({ callee, args, .. }) => {
      let callee_name = callee.getName().unwrap()
      let uses : Array[Operand] = Array::new()
      uses.push(Label(callee_name))
      for arg in args {
        match arg.asValueEnum() {
          ConstantInt(c) => uses.push(Imm(c.getValueAsInt64()))
          ConstantFP(f) => uses.push(FImm(f.value))
          _ => {
            guard value_map.get(arg) is Some(op) else {
              raise IRTranslateError(
                "CallInst: argument operand not found in value map",
              )
            }
            uses.push(op)
          }
        }
      }
      let defs : Array[Operand] = Array::new()
      if !(inst.getType().asTypeEnum() is VoidType(_)) {
        let ret_op = if inst.getType().isIEEELikeFPTy() {
          value_map.bind_llvmvalue_to_vfreg(inst)
        } else {
          value_map.bind_llvmvalue_to_vreg(inst)
        }
        defs.push(ret_op)
      }
      let call_inst = Instruction::{ opcode: Call, defs, uses }
      [call_inst]
    }
    ExtractValueInst(_) => {
      println("Warning: ExtractValueInst is not supported yet.")
      panic()
    }
    InsertValueInst(_) => {
      println("Warning: InsertValueInst is not supported yet.")
      panic()
    }
  }
}
