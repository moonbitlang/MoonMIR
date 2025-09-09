///|
traitalias @IR.Value as LLVMValue

///|
traitalias @IR.Instruction as LLVMInstruction

///|
typealias @IR.Function as LLVMFunction

///|
pub suberror IRTranslateError String derive(Show)

///|
priv struct ValueMap {
  map : Map[&@IR.Value, Operand]
  mut vreg_cnt : Int
  mut vfreg_cnt : Int
}

///|
fn ValueMap::new() -> ValueMap {
  ValueMap::{ map: Map::new(), vreg_cnt: 0, vfreg_cnt: 0 }
}

///|
fn ValueMap::add_vreg(self : Self, val : &LLVMValue) -> Operand {
  let i = self.vreg_cnt
  let op = VReg(i)
  self.map[val] = op
  self.vreg_cnt += 1
  op
}

///|
fn ValueMap::add_vfreg(self : Self, val : &LLVMValue) -> Operand {
  let i = self.vfreg_cnt
  let op = VFReg(i)
  self.map[val] = op
  self.vfreg_cnt += 1
  op
}

///|
fn ValueMap::add_mem(self : Self, val : &LLVMValue, offset : Int) -> Operand {
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
      let op = value_map.add_vfreg(arg)
      params.push(op)
    } else {
      let op = value_map.add_vreg(arg)
      params.push(op)
    }
  }

  // Get BasicBlocks labels
  let name = func.getName().unwrap_or("unnamed")
  for i, llvm_bb in func.basicBlocks {
    let label = "label.\{i}"
    value_map.map[llvm_bb] = Label(label)
  }
  let body : Array[BasicBlock] = Array::new()
  for i, llvm_bb in func.basicBlocks {
    let label = "label.\{i}"
    let bb = BasicBlock::from_llvm_bb(llvm_bb, value_map, stack_size, label)
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
  let insts : Array[Instruction] = Array::new()
  for inst in llvm_bb.instIter() {
    let minsts = Instruction::from_llvm_inst(inst, value_map, stack_size)
    minsts.each(m => insts.push(m))
  }
  let bb = BasicBlock::{ label, insts, parent: None }
  bb
}

///|
fn Instruction::from_llvm_inst(
  inst : &@IR.Instruction,
  value_map : ValueMap,
  stack_size : Ref[Int],
) -> Array[Instruction] raise {
  let ctx = inst.getContext()
  let mod = inst.getModule()
  let data_layout = mod.getDataLayout()
  match inst.asInstEnum() {
    AllocaInst({ data_ty, .. }) => {
      let data_size = data_layout.getTypeAllocSize(data_ty)
      let offset = stack_size.val
      stack_size.val += data_size
      let _ = value_map.add_mem(inst, offset)
      []
    }
    LoadInst({ vty, ptr, .. }) => {
      guard value_map.get(ptr) is Some(ptr_op) else {
        raise IRTranslateError(
          "LoadInst: pointer operand not found in value map",
        )
      }
      let op = if vty.isIEEELikeFPTy() {
        value_map.add_vfreg(inst)
      } else {
        value_map.add_vreg(inst)
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
      guard value_map.get(value) is Some(value_op) else {
        raise IRTranslateError(
          "StoreInst: value operand not found in value map",
        )
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
        _ =>
          raise IRTranslateError(
            "Unsupported BinaryInst opcode {\{opcode}} and data size {\{data_size}}",
          )
      }
      let def_op = if lhs.getType().isIEEELikeFPTy() {
        value_map.add_vfreg(inst)
      } else {
        value_map.add_vreg(inst)
      }
      guard value_map.get(lhs) is Some(lhs_op) else {
        raise IRTranslateError("BinaryInst: lhs operand not found in value map")
      }
      guard value_map.get(rhs) is Some(rhs_op) else {
        raise IRTranslateError("BinaryInst: rhs operand not found in value map")
      }
      let minst = Instruction::{
        opcode,
        defs: [def_op],
        uses: [lhs_op, rhs_op],
      }
      [minst]
    }
    // TODO: Should be Branch Inst sometimes
    ICmpInst({ predicate, lhs, rhs, .. }) => {
      let opcode = match predicate {
        EQ => Eq
        NE => Ne
        UGT | SGT => Gt
        UGE | SGE => Ge
        ULT | SLT => Lt
        ULE | SLE => Le
      }
      let def_op = value_map.add_vreg(inst)
      guard value_map.get(lhs) is Some(lhs_op) else {
        raise IRTranslateError("ICmpInst: lhs operand not found in value map")
      }
      guard value_map.get(rhs) is Some(rhs_op) else {
        raise IRTranslateError("ICmpInst: rhs operand not found in value map")
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
      let def_op = value_map.add_vreg(inst)
      guard value_map.get(lhs) is Some(lhs_op) else {
        raise IRTranslateError("FCmpInst: lhs operand not found in value map")
      }
      guard value_map.get(rhs) is Some(rhs_op) else {
        raise IRTranslateError("FCmpInst: rhs operand not found in value map")
      }
      let minst = Instruction::{
        opcode,
        defs: [def_op],
        uses: [lhs_op, rhs_op],
      }
      [minst]
    }
    BranchInst(_) => ...
    SwitchInst(_) => ...
    PHINode(_) => ...
    CastInst({ to_ty, from_val, opcode: cast_op, .. }) => ...
    GetElementPtrInst(_) => ...
    SelectInst(_) => ...
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
    CallInst(_) => ...
    ExtractValueInst(_) => ...
    InsertValueInst(_) => ...
  }
}
