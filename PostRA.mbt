///|
typealias @priority_queue.T as PriorityQueue

///|
pub suberror PostRAError String derive(Show)

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
  self.call_inst_transform()
  // Step 3: Promote return value
  // rewrite `ret v` to `mov ret_reg, v; ret`
  self.promote_ret()

  // Setp 4: Insert prologue and epilogue
  // Insert sp, fp modification instructions
  // Insert ra save/restore instructions (if call instructions exist)
  self.prologue_epilogue_insertion()
  // Step 5: Adjust Stack
  // We now have three kinds of mem
  // 1. Mem(FromePtr, offset)
  // 2. Mem(StackPtr, offset)
  // 3. Mem(FramePtrPrim, offset)
  // FramePtr = StackPtr + var_stack_size + reg_stack_size
  // FromePtrPrim = StackPtr + var_stack_size
  // Hence:
  // Mem(FramePtr, offset) -> Mem(StackPtr, offset + var_stack_size + reg_stack_size)
  // Mem(FramePtrPrim, offset) -> Mem(StackPtr, offset + var_stack_size)
  self.adjust_mem_operands()
}

///|
fn Function::group_registers(self : Function) -> Unit raise PostRAError {
  self.group_arg_registers()
  self.group_call_registers()
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
fn Function::group_arg_registers(self : Function) -> Unit {
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
      _ => ()
      //_ => raise PostRAError("Parameter is not a register")
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

// for `call func_name, %r4, %r1, %r7`
// first, collect all free registers
// if %a0 is free, use %a0 for %r4
// if %a1 is free, use %a1 for %r1
// if %a2 is free, use %a2 for %r7
// if %a0 is not free, do nothing for %r4, others same

///|
fn group_call_registers(self : Function) -> Unit {
  let (free_regs, free_fregs) = self.collect_free_regs()
  let free_regs = Set::from_array(free_regs.iter().collect())
  let free_fregs = Set::from_array(free_fregs.iter().collect())
  let replace_map : Map[Operand, Operand] = Map::new()
  let call_insts = self.collect_insts_by_opcode(Call)
  for inst in call_insts {
    for i, arg in inst.uses[1:] {
      match arg {
        Reg(_) as r if !replace_map.contains(r) && free_regs.contains(AReg(i)) => {
          replace_map.set(r, AReg(i))
          free_regs.remove(AReg(i))
        }
        FReg(_) as fr if !replace_map.contains(fr) &&
          free_fregs.contains(FAReg(i)) => {
          replace_map.set(fr, FAReg(i))
          free_fregs.remove(FAReg(i))
        }
        _ => ()
      }
    }
  }
  let ret_insts = self.collect_insts_by_opcode(Ret)
  for inst in ret_insts {
    if inst is { defs: [v], .. } {
      match v {
        Reg(_) as r if !replace_map.contains(r) && free_regs.contains(AReg(0)) => {
          replace_map.set(r, AReg(0))
          free_regs.remove(AReg(0))
        }
        FReg(_) as fr if !replace_map.contains(fr) &&
          free_fregs.contains(FAReg(0)) => {
          replace_map.set(fr, FAReg(0))
          free_fregs.remove(FAReg(0))
        }
        _ => ()
      }
    }
  }
  replace_operand_in_function(self, replace_map)
}

///|
///
/// After grouping arg registers and callee saved registers,
/// other registers need to be grouped.
/// Some are temporary registers,
/// if temp registers are not enough, use arg registers
/// if still not enough, use saved registers
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

// make call inst like `%t1 = call func_name, %t4, %t2, %s3`
// to
// ```
// %a0 = movq %t4
// %a1 = movq %t2
// %a2 = movq %s3
// call func_name
// %t1 = movq %a0
// ```
// be careful the special case: call func_name, %a3, %a2, % a1, %a0

///|
fn Function::call_inst_transform(self : Function) -> Unit {
  let arch_config = self.getArchConfig()
  let { num_arg_regs, num_arg_fregs, .. } = arch_config
  for bb in self.body {
    let new_insts : Array[Instruction] = Array::new()
    for inst in bb.insts {
      match inst {
        { opcode: Call, defs, uses: [func_label, .. args], livein, liveout, .. } => {
          // Separate integer and floating-point arguments
          let mut int_args : Array[(Int, Operand)] = []
          let mut fp_args : Array[(Int, Operand)] = []
          let mut stack_args : Array[Operand] = []
          for arg in args {
            match arg {
              FReg(_) | FAReg(_) | FTReg(_) | FSReg(_) | FImm(_) =>
                if fp_args.length() < num_arg_fregs {
                  fp_args.push((fp_args.length(), arg))
                } else {
                  stack_args.push(arg)
                }
              _ =>
                if int_args.length() < num_arg_regs {
                  int_args.push((int_args.length(), arg))
                } else {
                  stack_args.push(arg)
                }
            }
          }

          // Handle integer arguments - need to be careful about dependencies
          let mut moves_before : Array[Instruction] = []

          // Build dependency graph for integer arguments
          let mut pending_moves : Array[(Operand, Operand)] = []
          let mut completed : Set[Int] = Set::new()
          for pair in int_args {
            let (idx, src) = pair
            let target = AReg(idx)
            pending_moves.push((target, src))
          }

          // Process moves that don't have dependencies first
          let mut progress = true
          while progress && !pending_moves.is_empty() {
            progress = false
            let mut remaining : Array[(Operand, Operand)] = []
            for move_pair in pending_moves {
              let (target, src) = move_pair

              // Check if this move can be done now
              let can_move = match (target, src) {
                (AReg(t_idx), AReg(s_idx)) =>
                  if t_idx == s_idx {
                    // No move needed
                    true
                  } else {
                    // Check if any pending move needs AReg(t_idx) as source
                    let mut blocked = false
                    for other_move in pending_moves {
                      let (_, other_src) = other_move
                      match other_src {
                        AReg(other_s_idx) if other_s_idx == t_idx => {
                          // This target is needed as source elsewhere
                          blocked = true
                          break
                        }
                        _ => ()
                      }
                    }
                    !blocked
                  }
                (AReg(_), _) => true // Non-AReg sources can always be moved
                _ => true
              }
              if can_move {
                match (target, src) {
                  (AReg(t_idx), AReg(s_idx)) if t_idx == s_idx => {
                    // No move needed
                    completed.add(t_idx)
                    progress = true
                  }
                  _ => {
                    moves_before.push(
                      Instruction::new(Movq, [target], [src], bb=Some(bb)),
                    )
                    match target {
                      AReg(idx) => completed.add(idx)
                      _ => ()
                    }
                    progress = true
                  }
                }
              } else {
                remaining.push(move_pair)
              }
            }
            pending_moves = remaining
          }

          // Handle any remaining circular dependencies
          if !pending_moves.is_empty() {
            let (free_regs, _) = self.collect_free_regs()
            for move_pair in pending_moves {
              let (target, src) = move_pair
              match (target, src) {
                (AReg(t_idx), AReg(s_idx)) if t_idx == s_idx => () // No move needed
                _ =>
                  match free_regs.pop_front() {
                    Some(temp_reg) => {
                      // Use free register for swap
                      moves_before.push(
                        Instruction::new(Movq, [temp_reg], [src], bb=Some(bb)),
                      )
                      moves_before.push(
                        Instruction::new(
                          Movq,
                          [target],
                          [temp_reg],
                          bb=Some(bb),
                        ),
                      )
                    }
                    None => {
                      // No free register, use stack
                      let old_stack_size = self.reg_stack_size
                      self.extend_reg_stack(8, 8)
                      let stack_offset = self.reg_stack_size - 8

                      // Store to stack
                      moves_before.push(
                        Instruction::new(
                          Storeq,
                          [],
                          [Mem(FramePtr, -stack_offset), src],
                          bb=Some(bb),
                        ),
                      )
                      // Load from stack
                      moves_before.push(
                        Instruction::new(
                          Loadq,
                          [target],
                          [Mem(FramePtr, -stack_offset)],
                          bb=Some(bb),
                        ),
                      )

                      // Adjust stack argument offsets if stack was extended
                      if self.reg_stack_size != old_stack_size {
                        for i, arg in stack_args {
                          match arg {
                            Mem(FramePtr, offset) =>
                              stack_args[i] = Mem(FramePtr, offset + 8)
                            _ => ()
                          }
                        }
                      }
                    }
                  }
              }
            }
          }

          // Handle floating-point arguments similarly
          let mut fp_pending_moves : Array[(Operand, Operand)] = []
          for pair in fp_args {
            let (idx, src) = pair
            let target = FAReg(idx)
            fp_pending_moves.push((target, src))
          }

          // Process floating-point moves
          for move_pair in fp_pending_moves {
            let (target, src) = move_pair
            match (target, src) {
              (FAReg(t_idx), FAReg(s_idx)) if t_idx == s_idx => () // No move needed
              _ =>
                moves_before.push(
                  Instruction::new(FMovD, [target], [src], bb=Some(bb)),
                )
            }
          }

          // Add all move instructions before the call
          for move_inst in moves_before {
            new_insts.push(move_inst)
          }
          let new_call = Instruction::{
            opcode: Call,
            defs: [],
            uses: [func_label],
            bb: Some(bb),
            livein,
            liveout,
          }
          new_insts.push(new_call)

          // Handle return value
          if !defs.is_empty() {
            let ret_val = defs[0]
            match ret_val {
              AReg(0) => () // Already in the right place for integer return
              FAReg(0) => () // Already in the right place for FP return
              FReg(_) | FTReg(_) | FSReg(_) | VFReg(_) =>
                // Floating-point return value
                new_insts.push(
                  Instruction::new(FMovD, [ret_val], [FAReg(0)], bb=Some(bb)),
                )
              _ =>
                // Integer return value
                new_insts.push(
                  Instruction::new(Movq, [ret_val], [AReg(0)], bb=Some(bb)),
                )
            }
          }
        }
        _ =>
          // Not a call instruction, keep as-is
          new_insts.push(inst)
      }
    }
    bb.insts = new_insts
  }
}

///|
fn Function::adjust_mem_operands(self : Function) -> Unit {
  let { var_stack_size, reg_stack_size, .. } = self
  let total_stack_size = var_stack_size + reg_stack_size
  for bb in self.body {
    for inst in bb.insts {
      for i, use_op in inst.uses {
        match use_op {
          Mem(StackPtr, offset) => inst.uses[i] = Mem(StackPtr, offset)
          Mem(FramePtr, offset) =>
            inst.uses[i] = Mem(StackPtr, offset + total_stack_size)
          Mem(FramePtrPrim, offset) =>
            inst.uses[i] = Mem(StackPtr, offset + var_stack_size)
          _ => ()
        }
      }
      for i, def_op in inst.defs {
        match def_op {
          Mem(StackPtr, offset) => inst.defs[i] = Mem(StackPtr, offset)
          Mem(FramePtr, offset) =>
            inst.defs[i] = Mem(StackPtr, offset + total_stack_size)
          Mem(FramePtrPrim, offset) =>
            inst.defs[i] = Mem(StackPtr, offset + var_stack_size)
          _ => ()
        }
      }
    }
  }
}

///|
fn Function::prologue_epilogue_insertion(self : Function) -> Unit {
  // Load and store callee-saved registers
  let sreg_stack_loc_map : Map[Operand, Operand] = Map::new()
  for bb in self.body {
    for inst in bb.insts {
      let defs_uses = inst.defs.copy()
      defs_uses.append(inst.uses.copy())
      for op in defs_uses {
        match op {
          SReg(_) as r =>
            if !sreg_stack_loc_map.contains(r) {
              self.extend_reg_stack(8, 8)
              let offset = self.reg_stack_size
              sreg_stack_loc_map.set(r, Mem(FramePtrPrim, -offset))
            }
          FSReg(_) as fr =>
            if !sreg_stack_loc_map.contains(fr) {
              self.extend_reg_stack(8, 8)
              let offset = self.reg_stack_size
              sreg_stack_loc_map.set(fr, Mem(FramePtrPrim, -offset))
            }
          _ => ()
        }
      }
    }
  }
  let has_call = self.has_inst_with_opcode(Call)
  if self.var_stack_size == 0 && self.reg_stack_size == 0 && !has_call {
    // No stack adjustment needed
    return
  }
  let prologue : Array[Instruction] = Array::new()
  self.extend_reg_stack(8, 8) // for storing old frame pointer
  let frame_ptr_loc = self.reg_stack_size
  let ra_loc : Int64? = if has_call {
    // Need to save/restore return address
    self.extend_reg_stack(8, 8) // for storing old return address
    Some(self.reg_stack_size)
  } else {
    None
  }
  if self.reg_stack_size > 0 {
    //self.extend_var_stack(8, 8) // align var stack to 8 bytes
    self.var_stack_size = (self.var_stack_size + 8 - 1) / 8 * 8 // align to 8 bytes
  }
  let total_stack_size = self.var_stack_size + self.reg_stack_size
  //let total_stack_size = (self.var_stack_size + self.reg_stack_size + 8 - 1) / 8 * 8 // align to 8 bytes

  // Move StackPtr
  let alloc_stack = Instruction::new(Addq, [StackPtr], [
    StackPtr,
    Imm(-total_stack_size),
  ])
  prologue.push(alloc_stack)

  // Store old FramePtr
  let store_fp = Instruction::new(Storeq, [], [
    Mem(FramePtr, -frame_ptr_loc),
    FramePtr,
  ])
  prologue.push(store_fp)
  if ra_loc is Some(ra_loc) {
    let store_ra = Instruction::new(Storeq, [], [
      Mem(FramePtr, -ra_loc),
      ReturnAddr,
    ])
    prologue.push(store_ra)
  }

  // Set new FramePtr
  let setup_fp = Instruction::new(Addq, [FramePtr], [
    StackPtr,
    Imm(total_stack_size),
  ])
  prologue.push(setup_fp)
  // Store callee-saved registers
  for pair in sreg_stack_loc_map {
    let (r, loc) = pair
    let store_inst = match r {
      SReg(_) => Instruction::new(Storeq, [], [loc, r], bb=None)
      FSReg(_) => Instruction::new(FStoreD, [], [loc, r], bb=None)
      _ => continue // should not happen
    }
    prologue.push(store_inst)
  }
  for bb in self.body {
    let new_insts : Array[Instruction] = Array::new()
    let restore_stack = Instruction::new(Addq, [StackPtr], [
      StackPtr,
      Imm(total_stack_size),
    ])
    let restore_fp = Instruction::new(Loadq, [FramePtr], [
      Mem(FramePtr, -frame_ptr_loc),
    ])
    let restore_ra = if ra_loc is Some(ra_loc) {
      Instruction::new(Loadq, [ReturnAddr], [Mem(FramePtr, -ra_loc)]) |> Some
    } else {
      None
    }
    let restore_sregs : Array[Instruction] = Array::new()
    for pair in sreg_stack_loc_map {
      let (r, loc) = pair
      let load_inst = match r {
        SReg(_) => Instruction::new(Loadq, [r], [loc], bb=None)
        FSReg(_) => Instruction::new(FLoadD, [r], [loc], bb=None)
        _ => continue // should not happen
      }
      restore_sregs.push(load_inst)
    }
    for inst in bb.insts {
      if inst.opcode is Ret {
        if restore_ra is Some(restore_ra) {
          new_insts.push(restore_ra)
        }
        new_insts.append(restore_sregs)
        new_insts.push(restore_fp)
        new_insts.push(restore_stack)
        new_insts.push(inst)
      } else {
        new_insts.push(inst)
      }
    }
    bb.insts = new_insts
  }
  for i in prologue.rev_iter() {
    self.body[0].insts.insert(0, i)
  }
}
