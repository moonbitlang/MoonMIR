///|
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

///|
pub fn Module::post_ra(self : Self) -> Unit raise PostRAError {
  self.functions.each(func => func.post_ra())
}

///|
fn Function::post_ra(self : Function) -> Unit raise PostRAError {
  for bb in self.body {
    bb.post_ra()
  }
}

///|
fn BasicBlock::post_ra(bb : BasicBlock) -> Unit raise PostRAError {
  let new_insts : Array[Instruction] = Array::new()
  for inst in bb.insts {
    inst.post_ra().each(new_inst => bb.insts.push(new_inst))
  }
  bb.insts = new_insts
}

///|
fn Instruction::post_ra(
  self : Instruction,
) -> Array[Instruction] raise PostRAError {
  let new_insts : Array[Instruction] = Array::new()
  match self {
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
