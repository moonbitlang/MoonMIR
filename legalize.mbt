//|

///|
pub suberror LegalizeError String derive(Show)

///|
pub fn Module::legalize(self : Self) -> Unit raise LegalizeError {
  if self.legalized {
    raise LegalizeError("Module is already legalized")
  }
  self.functions.each(f => f.legalize())
}

///|
pub fn Function::legalize(func : Function) -> Unit raise LegalizeError {
  if func.legalized {
    raise LegalizeError("Function is already legalized")
  }
  for bb in func.body {
    bb.legalize()
  }
}

///|
pub fn BasicBlock::legalize(self : BasicBlock) -> Unit raise LegalizeError {
  let new_insts : Array[Instruction] = Array::new()
  for inst in self.insts {
    inst.legalize().each(new_inst => new_insts.push(new_inst))
  }
  self.insts = new_insts
}

///|
pub fn Instruction::legalize(
  self : Instruction,
) -> Array[Instruction] raise LegalizeError {
  if false {
    raise LegalizeError("Instruction legalization not implemented yet")
  }
  [self] // Placeholder: return the instruction unchanged
  //match inst.opcode {
  //  Call => {
  //    // Handle call instruction - need to spill excess arguments to stack
  //    let mut result : Array[Instruction] = []
  //
  //    // First operand is the function label
  //    let func_label = if inst.uses.length() > 0 {
  //      inst.uses[0]
  //    } else {
  //      raise LegalizeError("Call instruction missing function label")
  //    }
  //
  //    // Process arguments
  //    let mut reg_count = 0
  //    let mut freg_count = 0
  //    let mut stack_offset = 0
  //    let final_uses : Array[Operand] = [func_label]
  //    for i = 1; i < inst.uses.length(); i = i + 1 {
  //      let arg = inst.uses[i]
  //      match arg {
  //        VReg(_) | Reg(_) =>
  //          if reg_count < config.max_num_call_regs {
  //            final_uses.push(arg)
  //            reg_count += 1
  //          } else {
  //            // Need to spill to stack
  //            let mem_loc = Mem(StackPtr, stack_offset)
  //            let store_inst = Instruction::{
  //              opcode: Storeq,
  //              defs: [],
  //              uses: [mem_loc, arg],
  //            }
  //            result.push(store_inst)
  //            final_uses.push(mem_loc)
  //            stack_offset += 8
  //          }
  //        Imm(_) =>
  //          if reg_count < config.max_num_call_regs {
  //            final_uses.push(arg)
  //            reg_count += 1
  //          } else {
  //            // Need to move immediate to stack
  //            let temp_vreg = vreg_alloc.alloc_vreg()
  //            let mov_inst = Instruction::{
  //              opcode: Movq,
  //              defs: [temp_vreg],
  //              uses: [arg],
  //            }
  //            result.push(mov_inst)
  //            let mem_loc = Mem(StackPtr, stack_offset)
  //            let store_inst = Instruction::{
  //              opcode: Storeq,
  //              defs: [],
  //              uses: [mem_loc, temp_vreg],
  //            }
  //            result.push(store_inst)
  //            final_uses.push(mem_loc)
  //            stack_offset += 8
  //          }
  //        VFReg(_) | FReg(_) =>
  //          if freg_count < config.max_num_call_fregs {
  //            final_uses.push(arg)
  //            freg_count += 1
  //          } else {
  //            // Need to spill to stack
  //            let mem_loc = Mem(StackPtr, stack_offset)
  //            let store_inst = Instruction::{
  //              opcode: FStoreD,
  //              defs: [],
  //              uses: [mem_loc, arg],
  //            }
  //            result.push(store_inst)
  //            final_uses.push(mem_loc)
  //            stack_offset += 8
  //          }
  //        FImm(_) =>
  //          if freg_count < config.max_num_call_fregs {
  //            final_uses.push(arg)
  //            freg_count += 1
  //          } else {
  //            // Need to move immediate to stack
  //            let temp_vfreg = vreg_alloc.alloc_vfreg()
  //            let mov_inst = Instruction::{
  //              opcode: FMovD,
  //              defs: [temp_vfreg],
  //              uses: [arg],
  //            }
  //            result.push(mov_inst)
  //            let mem_loc = Mem(StackPtr, stack_offset)
  //            let store_inst = Instruction::{
  //              opcode: FStoreD,
  //              defs: [],
  //              uses: [mem_loc, temp_vfreg],
  //            }
  //            result.push(store_inst)
  //            final_uses.push(mem_loc)
  //            stack_offset += 8
  //          }
  //        _ => final_uses.push(arg) // Labels, Mem, StackPtr - pass through
  //      }
  //    }
  //    result.push(Instruction::{
  //      opcode: inst.opcode,
  //      defs: inst.defs.copy(),
  //      uses: final_uses,
  //    })
  //    result
  //  }
  //  _ => [inst] // Other instructions pass through unchanged
  //}
}
