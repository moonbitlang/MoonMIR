///|
typealias @priority_queue.T as PriorityQueue

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
pub fn Module::post_ra(self : Self) -> Module raise PostRAError {
  self.functions.each(func => func.post_ra())
  self
}

///|
fn Function::post_ra(self : Function) -> Unit raise PostRAError {
  // Step 1: Group registers
  self.group_registers()

  // Step 2:
  //self.order_call_arguments()
  // Step 3: Promote return value
  // rewrite `ret v` to `mov ret_reg, v; ret`
  self.promote_ret()
}

///|
fn Function::group_registers(self : Function) -> Unit raise PostRAError {
  self.group_arg_registers()
  self.group_callee_saved_registers()
  self.group_normal_registers()
}

///|
/// After Register Allocation, we get MIR like:
/// func foo(%r4, %r5, %r3) {
///   ...
/// }
/// rewrite  %r4 -> %a0
///          %r5 -> %a1
///          %r3 -> %a2
fn Function::group_arg_registers(self : Function) -> Unit raise PostRAError {
  // Group Arg registers
  let reg_areg_map : Map[Operand, Operand] = Map::new()
  let mut p_arg_reg : Int = 0
  let mut p_arg_freg : Int = 0
  for p in self.params {
    match p {
      Reg(_) as p => {
        reg_areg_map.set(p, AReg(p_arg_reg))
        p_arg_reg += 1
      }
      FReg(_) as p => {
        reg_areg_map.set(p, FAReg(p_arg_freg))
        p_arg_freg += 1
      }
      _ => raise PostRAError("Parameter is not a register")
    }
  }
  replace_operand_in_function(self, reg_areg_map)
}

///|
priv struct OperandUsage(Operand, Int) derive(Eq)

///|
impl Compare for OperandUsage with compare(self, other) {
  let OperandUsage(_, a) = self
  let OperandUsage(_, b) = other
  a.compare(b)
}

///|
/// Some Registers we may want to use saved registers
/// for example
/// %r3 = ...
/// call foo, %r0, %r2
/// ... = %r3
///
/// we may want to make %r3 to a saved register
fn Function::group_callee_saved_registers(self : Function) -> Unit {
  let reg_usage : Map[Operand, Int] = Map::new()
  let freg_usage : Map[Operand, Int] = Map::new()
  let call_insts = self.collect_insts_by_opcode(Call)
  for inst in call_insts {
    for op in inst.liveout {
      match op {
        Reg(_) as r => {
          let count = reg_usage.get(r).unwrap_or(0)
          reg_usage.set(r, count + 1)
        }
        FReg(_) as fr => {
          let count = freg_usage.get(fr).unwrap_or(0)
          freg_usage.set(fr, count + 1)
        }
        _ => ()
      }
    }
  }
  let reg_usage_pq : PriorityQueue[OperandUsage] = PriorityQueue::new()
  let freg_usage_pq : PriorityQueue[OperandUsage] = PriorityQueue::new()
  for info in reg_usage {
    let (r, count) = info
    reg_usage_pq.push(OperandUsage(r, count))
  }
  for info in freg_usage {
    let (fr, count) = info
    freg_usage_pq.push(OperandUsage(fr, count))
  }
  let { num_saved_regs, num_saved_fregs, .. } = self.getArchConfig()
  let replace_map : Map[Operand, Operand] = Map::new()
  let mut saved_reg_idx : Int = 0
  while !reg_usage_pq.is_empty() && saved_reg_idx < num_saved_regs {
    let OperandUsage(r, _) = reg_usage_pq.pop().unwrap()
    replace_map.set(r, SReg(saved_reg_idx))
    saved_reg_idx += 1
  }
  let mut saved_freg_idx : Int = 0
  while !freg_usage_pq.is_empty() && saved_freg_idx < num_saved_fregs {
    let OperandUsage(fr, _) = freg_usage_pq.pop().unwrap()
    replace_map.set(fr, FSReg(saved_freg_idx))
    saved_freg_idx += 1
  }
  replace_operand_in_function(self, replace_map)
}

// After grouping arg registers and callee saved registers,
// other registers need to be grouped.
// Some are temporary registers,
// if temp registers are not enough, use arg registers
// if still not enough, use saved registers

///|
fn group_normal_registers(self : Function) -> Unit raise PostRAError {
  let (free_regs, free_fregs) = self.collect_free_regs()
  let replace_map : Map[Operand, Operand] = Map::new()
  for bb in self.body {
    for inst in bb.insts {
      inst.defs.each(def_op => match def_op {
        Reg(_) as r if !replace_map.contains(r) =>
          if free_regs.pop_front() is Some(new_r) {
            replace_map.set(r, new_r)
          } else {
            raise PostRAError("Not enough registers")
          }
        FReg(_) as fr if !replace_map.contains(fr) =>
          if free_fregs.pop_front() is Some(new_fr) {
            replace_map.set(fr, new_fr)
          } else {
            raise PostRAError("Not enough floating point registers")
          }
        _ => ()
      })
    }
  }
  replace_operand_in_function(self, replace_map)
}

///|
fn collect_free_regs(self : Function) -> (Deque[Operand], Deque[Operand]) {
  let free_regs : Set[Operand] = Set::new()
  let free_fregs : Set[Operand] = Set::new()
  let argh_config = self.getArchConfig()
  let { num_arg_regs, num_arg_fregs, .. } = argh_config
  let { num_temp_regs, num_temp_fregs, .. } = argh_config
  let { num_saved_regs, num_saved_fregs, .. } = argh_config
  for i in 0..<num_arg_regs {
    free_regs.add(AReg(i))
  }
  for i in 0..<num_arg_fregs {
    free_fregs.add(FAReg(i))
  }
  for i in 0..<num_temp_regs {
    free_regs.add(TReg(i))
  }
  for i in 0..<num_temp_fregs {
    free_fregs.add(FTReg(i))
  }
  for i in 0..<num_saved_regs {
    free_regs.add(SReg(i))
  }
  for i in 0..<num_saved_fregs {
    free_fregs.add(FSReg(i))
  }
  for bb in self.body {
    for inst in bb.insts {
      inst.defs.each(op => free_regs.remove(op))
      inst.uses.each(op => free_regs.remove(op))
    }
  }
  let new_free_regs : Deque[Operand] = Deque::new()
  let new_free_fregs : Deque[Operand] = Deque::new()
  free_regs
  .iter()
  .filter(op => op is TReg(_))
  .each(op => new_free_regs.push_back(op))
  free_regs
  .iter()
  .filter(op => op is AReg(_))
  .each(op => new_free_regs.push_back(op))
  free_regs
  .iter()
  .filter(op => op is SReg(_))
  .each(op => new_free_regs.push_back(op))
  free_fregs
  .iter()
  .filter(op => op is FTReg(_))
  .each(op => new_free_fregs.push_back(op))
  free_fregs
  .iter()
  .filter(op => op is FAReg(_))
  .each(op => new_free_fregs.push_back(op))
  free_fregs
  .iter()
  .filter(op => op is FSReg(_))
  .each(op => new_free_fregs.push_back(op))
  (new_free_regs, new_free_fregs)
}

///|
fn replace_operand_in_function(
  func : Function,
  replace_map : Map[Operand, Operand],
) -> Unit {
  for bb in func.body {
    for inst in bb.insts {
      for i, def_op in inst.defs {
        if replace_map.get(def_op) is Some(new_def_op) {
          inst.defs[i] = new_def_op
        }
      }
      for i, use_op in inst.uses {
        if replace_map.get(use_op) is Some(new_use_op) {
          inst.uses[i] = new_use_op
        }
      }
      for op in inst.livein {
        if replace_map.get(op) is Some(new_op) {
          inst.livein.remove(op)
          inst.livein.add(new_op)
        }
      }
      for op in inst.liveout {
        if replace_map.get(op) is Some(new_op) {
          inst.liveout.remove(op)
          inst.liveout.add(new_op)
        }
      }
    }
    for op in bb.livein {
      if replace_map.get(op) is Some(new_op) {
        bb.livein.remove(op)
        bb.livein.add(new_op)
      }
    }
    for op in bb.liveout {
      if replace_map.get(op) is Some(new_op) {
        bb.liveout.remove(op)
        bb.liveout.add(new_op)
      }
    }
  }
}

///|
fn Function::promote_ret(self : Function) -> Unit raise PostRAError {
  for bb in self.body {
    let new_insts : Array[Instruction] = Array::new()
    for inst in bb.insts {
      match inst {
        { opcode: Ret, defs: [], uses: [v], bb, .. } => {
          match v {
            AReg(0) | FReg(0) =>
              // already in return register
              // do nothing
              ignore(0)
            AReg(_) | TReg(_) | SReg(_) as v => {
              let inst = Instruction::new(Movq, [AReg(0)], [v], bb~)
              new_insts.push(inst)
            }
            FAReg(_) | FTReg(_) | FSReg(_) as v => {
              let inst = Instruction::new(FMovD, [FReg(0)], [v], bb~)
              new_insts.push(inst)
            }
            Imm(i) => {
              let inst = Instruction::new(Movq, [AReg(0)], [Imm(i)], bb~)
              new_insts.push(inst)
            }
            Mem(base, offset) => {
              let inst = Instruction::new(
                Loadq,
                [AReg(0)],
                [Mem(base, offset)],
                bb~,
              )
              new_insts.push(inst)
            }
            _ => raise PostRAError("Unsupported operand for return")
          }
          let ret_inst = Instruction::new(Ret, [], [], bb~)
          new_insts.push(ret_inst)
        }
        inst => new_insts.push(inst)
      }
    }
    bb.insts = new_insts
  }
}

/////|
//fn BasicBlock::post_ra(bb : BasicBlock) -> Unit raise PostRAError {
//  let new_insts : Array[Instruction] = Array::new()
//  for inst in bb.insts {
//    inst.post_ra().each(new_inst => bb.insts.push(new_inst))
//  }
//  bb.insts = new_insts
//}
//
/////|
//fn Instruction::post_ra(
//  self : Instruction,
//) -> Array[Instruction] raise PostRAError {
//  let new_insts : Array[Instruction] = Array::new()
//  match self {
//    { opcode: Ret, defs: [], uses: [v], bb, .. } => {
//      match v {
//        Reg(_) => {
//          let inst = Instruction::new(Movq, [Reg(0)], [v], bb~)
//          new_insts.push(inst)
//        }
//        FReg(_) => {
//          let inst = Instruction::new(FMovD, [FReg(0)], [v], bb~)
//          new_insts.push(inst)
//        }
//        Imm(i) => {
//          let inst = Instruction::new(Movq, [Reg(0)], [Imm(i)], bb~)
//          new_insts.push(inst)
//        }
//        Mem(base, offset) => {
//          let inst = Instruction::new(Loadq, [Reg(0)], [Mem(base, offset)], bb~)
//          new_insts.push(inst)
//        }
//        _ => raise PostRAError("Unsupported operand for return")
//      }
//      let ret_inst = Instruction::new(Ret, [], [], bb~)
//      new_insts.push(ret_inst)
//    }
//    inst => new_insts.push(inst)
//  }
//  new_insts
//}
