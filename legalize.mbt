//|

///|
pub suberror LegalizeError String derive(Show)

///|
// Helper to create a memory operand for accessing caller's stack frame
// 
// CALLING CONVENTION NOTE:
// In standard calling conventions (e.g., RISC-V, x86-64), spilled parameters
// are passed on the caller's stack. The callee accesses them using:
// 
// 1. Negative offsets from SP: (sp - 8), (sp - 16), etc.
//    - Parameters are "above" the current stack pointer
//    - This assumes SP points to the top of callee's frame
// 
// 2. Positive offsets from FP: (fp + 16), (fp + 24), etc.
//    - If using frame pointer, parameters are after saved registers
//    - More stable when SP changes during function execution
// 
// VM Implementation:
// The VM now supports negative stack offsets, allowing us to properly
// implement the calling convention where spilled parameters are accessed
// at negative offsets from the stack pointer.
fn make_caller_stack_param(offset : Int) -> Operand {
  // Correct implementation: access caller's stack with negative offset
  // The offset is already the byte offset from the first spilled parameter
  // We add 8 to skip over the return address slot
  Mem(StackPtr, -(8 + offset))
}

///|
pub struct LegalizeConfig {
  // Maximum Call Registers
  // If Exceeded, will spill to stack
  max_num_call_regs : Int
  max_num_call_fregs : Int
  // Whether to support select instruction
  // If false, will lower to branches
  //support_select : Bool
}

///|
// Legacy interface for compatibility
pub fn Module::legalize(self : Self) -> Module raise {
  self.legalize_with_config(LegalizeConfig::{
    max_num_call_regs: 8,
    max_num_call_fregs: 8,
  })
}

///|
pub fn Module::legalize_with_config(
  self : Self,
  config : LegalizeConfig,
) -> Module raise {
  let new_module = Module::new()
  self.functions.each(func => {
    let legalized_func = legalize_func(func, config)
    new_module.functions.push(legalized_func)
  })
  new_module
}

///|
// Helper to allocate a new virtual register
pub(all) struct VRegAllocator {
  mut next_vreg : Int
  mut next_vfreg : Int
}

///|
fn VRegAllocator::new(start_vreg : Int, start_vfreg : Int) -> VRegAllocator {
  VRegAllocator::{ next_vreg: start_vreg, next_vfreg: start_vfreg }
}

///|
fn VRegAllocator::alloc_vreg(self : VRegAllocator) -> Operand {
  let reg = VReg(self.next_vreg)
  self.next_vreg += 1
  reg
}

///|
fn VRegAllocator::alloc_vfreg(self : VRegAllocator) -> Operand {
  let reg = VFReg(self.next_vfreg)
  self.next_vfreg += 1
  reg
}

///|
pub fn legalize_func(
  func : Function,
  config : LegalizeConfig,
) -> Function raise {
  let new_func = Function::new(func.name)

  // Find the maximum vreg/vfreg numbers to avoid conflicts
  let mut max_vreg = 0
  let mut max_vfreg = 0
  for param in func.params {
    match param {
      VReg(n) => if n > max_vreg { max_vreg = n }
      VFReg(n) => if n > max_vfreg { max_vfreg = n }
      _ => ()
    }
  }
  for bb in func.body {
    for inst in bb.insts {
      for op in inst.defs {
        match op {
          VReg(n) => if n > max_vreg { max_vreg = n }
          VFReg(n) => if n > max_vfreg { max_vfreg = n }
          _ => ()
        }
      }
      for op in inst.uses {
        match op {
          VReg(n) => if n > max_vreg { max_vreg = n }
          VFReg(n) => if n > max_vfreg { max_vfreg = n }
          _ => ()
        }
      }
    }
  }
  let vreg_alloc = VRegAllocator::new(max_vreg + 1, max_vfreg + 1)

  // Track how many registers of each type we've seen
  let mut reg_count = 0
  let mut freg_count = 0
  let mut stack_offset = 0

  // Maps from old parameter VReg/VFReg ID to new location (for spilled params)
  let param_spill_map : Map[Int, Operand] = Map::new()

  // Process parameters - spilled parameters become Mem operands
  // In proper calling conventions, spilled parameters are in the caller's stack frame,
  // so they are accessed at negative offsets from our stack pointer (sp-8, sp-16, etc.)
  // The VM now supports negative offsets, allowing correct implementation.

  // Track offset for spilled parameters (will be negative when used)
  let mut param_stack_offset = 0 // Byte offset from first spilled param
  for param in func.params {
    match param {
      VReg(id) =>
        if reg_count < config.max_num_call_regs {
          // Keep in register
          new_func.params.push(param)
          reg_count += 1
        } else {
          // Parameter is passed on caller's stack
          let mem_loc = make_caller_stack_param(param_stack_offset)
          new_func.params.push(mem_loc)
          // Map the old VReg ID to the new Mem location for instruction rewriting
          param_spill_map[id] = mem_loc
          param_stack_offset += 8 // Next parameter
          stack_offset += 8 // Track total stack space needed
        }
      VFReg(id) =>
        if freg_count < config.max_num_call_fregs {
          // Keep in register
          new_func.params.push(param)
          freg_count += 1
        } else {
          // Parameter is passed on caller's stack
          let mem_loc = make_caller_stack_param(param_stack_offset)
          new_func.params.push(mem_loc)
          // Map the old VFReg ID to the new Mem location
          param_spill_map[id] = mem_loc
          param_stack_offset += 8 // Next parameter
          stack_offset += 8 // Track total stack space needed
        }
      _ => new_func.params.push(param)
    }
  }

  // Update stack size if we spilled parameters
  new_func.stack_size = func.stack_size + stack_offset

  // Legalize each basic block
  for bb in func.body {
    let legalized_bb = legalize_basic_block(
      bb, config, param_spill_map, vreg_alloc,
    )
    new_func.body.push(legalized_bb)
  }
  new_func
}

///|
pub fn legalize_basic_block(
  bb : BasicBlock,
  config : LegalizeConfig,
  param_spill_map : Map[Int, Operand],
  vreg_alloc : VRegAllocator,
) -> BasicBlock raise {
  let new_bb = BasicBlock::new(bb.label)
  new_bb.parent = bb.parent

  // Process all instructions, replacing spilled parameter references
  for inst in bb.insts {
    // Replace any uses of spilled parameters with their memory locations
    let mut modified = false
    let new_uses : Array[Operand] = []
    for use_op in inst.uses {
      match use_op {
        VReg(id) =>
          match param_spill_map.get(id) {
            Some(mem_loc) => {
              // This VReg was a spilled parameter, use memory location instead
              new_uses.push(mem_loc)
              modified = true
            }
            None => new_uses.push(use_op)
          }
        VFReg(id) =>
          match param_spill_map.get(id) {
            Some(mem_loc) => {
              // This VFReg was a spilled parameter, use memory location instead
              new_uses.push(mem_loc)
              modified = true
            }
            None => new_uses.push(use_op)
          }
        _ => new_uses.push(use_op)
      }
    }
    let inst_to_process = if modified {
      Instruction::{
        opcode: inst.opcode,
        defs: inst.defs.copy(),
        uses: new_uses,
      }
    } else {
      inst
    }

    // Now legalize the instruction (handle Call spillage, etc.)
    let legalized_insts = legalize_instruction(
      inst_to_process, config, vreg_alloc,
    )
    for lin in legalized_insts {
      new_bb.insts.push(lin)
    }
  }
  new_bb
}

///|
pub fn legalize_instruction(
  inst : Instruction,
  config : LegalizeConfig,
  vreg_alloc : VRegAllocator,
) -> Array[Instruction] raise {
  match inst.opcode {
    Call => {
      // Handle call instruction - need to spill excess arguments to stack
      let mut result : Array[Instruction] = []

      // First operand is the function label
      let func_label = if inst.uses.length() > 0 {
        inst.uses[0]
      } else {
        raise LegalizeError("Call instruction missing function label")
      }

      // Process arguments
      let mut reg_count = 0
      let mut freg_count = 0
      let mut stack_offset = 0
      let final_uses : Array[Operand] = [func_label]
      for i = 1; i < inst.uses.length(); i = i + 1 {
        let arg = inst.uses[i]
        match arg {
          VReg(_) | Reg(_) =>
            if reg_count < config.max_num_call_regs {
              final_uses.push(arg)
              reg_count += 1
            } else {
              // Need to spill to stack
              let mem_loc = Mem(StackPtr, stack_offset)
              let store_inst = Instruction::{
                opcode: Storeq,
                defs: [],
                uses: [mem_loc, arg],
              }
              result.push(store_inst)
              final_uses.push(mem_loc)
              stack_offset += 8
            }
          Imm(_) =>
            if reg_count < config.max_num_call_regs {
              final_uses.push(arg)
              reg_count += 1
            } else {
              // Need to move immediate to stack
              let temp_vreg = vreg_alloc.alloc_vreg()
              let mov_inst = Instruction::{
                opcode: Movq,
                defs: [temp_vreg],
                uses: [arg],
              }
              result.push(mov_inst)
              let mem_loc = Mem(StackPtr, stack_offset)
              let store_inst = Instruction::{
                opcode: Storeq,
                defs: [],
                uses: [mem_loc, temp_vreg],
              }
              result.push(store_inst)
              final_uses.push(mem_loc)
              stack_offset += 8
            }
          VFReg(_) | FReg(_) =>
            if freg_count < config.max_num_call_fregs {
              final_uses.push(arg)
              freg_count += 1
            } else {
              // Need to spill to stack
              let mem_loc = Mem(StackPtr, stack_offset)
              let store_inst = Instruction::{
                opcode: FStoreD,
                defs: [],
                uses: [mem_loc, arg],
              }
              result.push(store_inst)
              final_uses.push(mem_loc)
              stack_offset += 8
            }
          FImm(_) =>
            if freg_count < config.max_num_call_fregs {
              final_uses.push(arg)
              freg_count += 1
            } else {
              // Need to move immediate to stack
              let temp_vfreg = vreg_alloc.alloc_vfreg()
              let mov_inst = Instruction::{
                opcode: FMovD,
                defs: [temp_vfreg],
                uses: [arg],
              }
              result.push(mov_inst)
              let mem_loc = Mem(StackPtr, stack_offset)
              let store_inst = Instruction::{
                opcode: FStoreD,
                defs: [],
                uses: [mem_loc, temp_vfreg],
              }
              result.push(store_inst)
              final_uses.push(mem_loc)
              stack_offset += 8
            }
          _ => final_uses.push(arg) // Labels, Mem, StackPtr - pass through
        }
      }
      result.push(Instruction::{
        opcode: inst.opcode,
        defs: inst.defs.copy(),
        uses: final_uses,
      })
      result
    }
    _ => [inst] // Other instructions pass through unchanged
  }
}
