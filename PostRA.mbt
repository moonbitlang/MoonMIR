
pub suberror PostRAError String derive(Show)

//pub fn Module::post_ra(self: Self) -> Module raise PostRAError {
//  //// This module performs post-register allocation optimizations and cleanups.
//  //// It includes tasks such as instruction scheduling, peephole optimizations,
//  //// and final adjustments to ensure the generated code is efficient and correct.
//  //
//  //// Step 1: Instruction Scheduling
//  //fn instruction_scheduling() {
//  //    // Reorder instructions to minimize stalls and improve pipeline efficiency.
//  //    // This may involve moving independent instructions closer together.
//  //}
//  //
//  //// Step 2: Peephole Optimizations
//  //fn peephole_optimizations() {
//  //    // Look for small patterns of instructions that can be replaced with more efficient sequences.
//  //    // Examples include eliminating redundant moves or combining multiple operations into one.
//  //}
//  //
//  //// Step 3: Final Adjustments
//  //fn final_adjustments() {
//  //    // Ensure that all instructions conform to the target architecture's constraints.
//  //    // This may involve adjusting immediate values, fixing up branch targets, etc.
//  //}
//  //
//  //// Execute the steps in order
//  //instruction_scheduling();
//  let mod = pre_adjustments(self)
//  let mod = peephole_optimizations(mod);
//  //final_adjustments();
//  mod
//}

pub fn Module::post_ra_adjustments(mod: Self) -> Module raise PostRAError {
  let new_module = Module::new()
  mod.functions.each(func => {
    let legalized_func = adjust_function(func)
    new_module.functions.push(legalized_func)
  })
  new_module
}

fn adjust_function(func: Function) -> Function raise PostRAError {
  let new_func = Function::new(func.name)
  func.params.each(param => new_func.params.push(param))
  for bb in func.body {
    let legalized_bb = adjust_basic_block(bb)
    new_func.body.push(legalized_bb)
  }
  new_func
}

fn adjust_basic_block(bb: BasicBlock) -> BasicBlock raise PostRAError {
  let new_bb = BasicBlock::new(bb.label)
  new_bb.parent = bb.parent
  for inst in bb.insts {
    let legalized_insts = adjust_instruction(inst)
    for lin in legalized_insts {
      new_bb.insts.push(lin)
    }
  }
  new_bb
}

fn adjust_instruction(inst: Instruction) -> Array[Instruction] raise PostRAError {
  let new_insts : Array[Instruction] = Array::new()
  match inst {
    { opcode: Ret, defs: [], uses: [v] } => {
      match v {
        Reg(_) => {
          let inst = Instruction::{ opcode: Movq, defs: [Reg(0)], uses: [v] }
          new_insts.push(inst)
        }
        FReg(_) => {
          let inst = Instruction::{ opcode: FMovD, defs: [FReg(0)], uses: [v] }
          new_insts.push(inst)
        }
        Imm(i) => {
          let inst = Instruction::{
            opcode: Movq,
            defs: [Reg(0)],
            uses: [Imm(i)],
          }
          new_insts.push(inst)
        }
        Mem(base, offset) => {
          let inst = Instruction::{
            opcode: Loadq,
            defs: [Reg(0)],
            uses: [Mem(base, offset)],
          }
          new_insts.push(inst)
        }
        _ => raise PostRAError("Unsupported operand for return")
      }
      let ret_inst = Instruction::{ opcode: Ret, defs: [], uses: [] }
      new_insts.push(ret_inst)
    }
    inst => new_insts.push(inst)
  }
  new_insts
}
