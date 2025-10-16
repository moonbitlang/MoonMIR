///|
typealias @deque.Deque

///|
pub fn live_analysis(func : Function) -> (Graph[Int], Graph[Int]) {
  let vreg_graph = Graph::new()
  let vfreg_graph = Graph::new()

  // Add all vregs and vfregs that have been created to the graph
  // This ensures no vreg is missing from the graph
  for i = 0; i < func.vreg_cnt; i = i + 1 {
    vreg_graph.add_node(i)
  }
  for i = 0; i < func.vfreg_cnt; i = i + 1 {
    vfreg_graph.add_node(i)
  }

  // add param regs to graph (they will already be added but this is harmless)
  for param in func.params {
    if param is VReg(p) {
      vreg_graph.add_node(p)
    } else if param is VFReg(p) {
      vfreg_graph.add_node(p)
    }
  }
  for param1 in func.params {
    for param2 in func.params {
      if param1 is VReg(p1) && param2 is VReg(p2) {
        vreg_graph.add_edge(p1, p2)
      } else if param1 is VFReg(p1) && param2 is VFReg(p2) {
        vfreg_graph.add_edge(p1, p2)
      }
    }
  }
  if func.body.is_empty() {
    return (vreg_graph, vfreg_graph)
  }
  let bb_queue : Deque[BasicBlock] = Deque::new()
  let visited_bb_labels : Set[String] = Set::new()

  // Initialize queue with terminal basic blocks (those ending with return)
  // If no terminal blocks marked, use the last basic block
  if func.terminal_basic_blocks.is_empty() {
    if func.body.length() > 0 {
      bb_queue.push_back(func.body[func.body.length() - 1])
    }
  } else {
    for terminal_bb in func.terminal_basic_blocks {
      bb_queue.push_back(terminal_bb)
    }
  }
  live_analysis_for_basic_blocks(
    bb_queue, visited_bb_labels, vreg_graph, vfreg_graph,
  )
  (vreg_graph, vfreg_graph)
}

///|
/// Fixed liveness analysis that handles loops correctly by iterating until fixed point
fn live_analysis_for_basic_blocks(
  bb_queue : Deque[BasicBlock],
  _visited_bb_labels : Set[String],
  vreg_graph : Graph[Int],
  vfreg_graph : Graph[Int],
) -> Unit {
  // First pass: visit all basic blocks to ensure all vregs are in the graph
  let all_bbs : Array[BasicBlock] = Array::new()
  let bb_set : Set[String] = Set::new()

  // Collect all basic blocks from the queue
  while !bb_queue.is_empty() {
    let bb = bb_queue.pop_front().unwrap()
    if !bb_set.contains(bb.label) {
      all_bbs.push(bb)
      bb_set.add(bb.label)

      // Add all defined registers to the graph early
      for inst in bb.insts {
        for def in inst.defs {
          match def {
            VReg(v) => vreg_graph.add_node(v)
            VFReg(v) => vfreg_graph.add_node(v)
            _ => ()
          }
        }
      }

      // Add predecessors to queue
      for pred in bb.preds {
        if !bb_set.contains(pred.label) {
          bb_queue.push_back(pred)
        }
      }
    }
  }

  // Iterate until fixed point
  let mut changed = true
  let max_iterations = 100 // Prevent infinite loops
  let mut iteration = 0
  while changed && iteration < max_iterations {
    changed = false
    iteration += 1

    // Process all basic blocks in reverse order (from end to start)
    for i = all_bbs.length() - 1; i >= 0; i = i - 1 {
      let bb = all_bbs[i]

      // Save old livein to detect changes
      let old_livein_size = bb.livein.length()

      // Recompute liveout from successors' livein
      bb.liveout.clear()
      for succ_label in bb.successors_label() {
        // Find successor block
        for other_bb in all_bbs {
          if other_bb.label == succ_label {
            other_bb.livein.each(o => bb.liveout.add(o))
            break
          }
        }
      }

      // Process instructions from back to front
      let mut next_livein : Set[Operand] = bb.liveout.copy()
      for inst in bb.insts.rev_iter() {
        // Set this instruction's liveout to be the next instruction's livein
        inst.liveout.clear()
        next_livein.each(o => inst.liveout.add(o))

        // Compute this instruction's livein
        live_analysis_for_instruction(inst)

        // Update next_livein for the previous instruction
        next_livein = inst.livein.copy()
      }

      // Update basic block's livein
      bb.livein.clear()
      if bb.insts.length() > 0 {
        bb.insts[0].livein.each(o => bb.livein.add(o))
      }

      // Check if livein changed
      if bb.livein.length() != old_livein_size {
        changed = true
      }
    }
  }

  // Build conflict graph from final liveness information
  for bb in all_bbs {
    for inst in bb.insts {
      let (live_vreg_set, live_fvreg_set) = spilt_vreg_and_vfreg(inst.livein)
      update_graph(vreg_graph, live_vreg_set)
      update_graph(vfreg_graph, live_fvreg_set)

      // Add conflict edges between defined registers and livein registers
      // A register being defined cannot use the same physical register as any register that is live at that point
      for def_op in inst.defs {
        match def_op {
          VReg(v) => {
            vreg_graph.add_node(v)
            // Add edge between defined vreg and all livein vregs
            for livein_vreg in live_vreg_set {
              vreg_graph.add_edge(v, livein_vreg)
            }
          }
          VFReg(v) => {
            vfreg_graph.add_node(v)
            // Add edge between defined vfreg and all livein vfregs
            for livein_vfreg in live_fvreg_set {
              vfreg_graph.add_edge(v, livein_vfreg)
            }
          }
          _ => ()
        }
      }

      // Also ensure all used registers are in the graph
      for used_op in inst.uses {
        match used_op {
          VReg(v) => vreg_graph.add_node(v)
          VFReg(v) => vfreg_graph.add_node(v)
          _ => ()
        }
      }

      // Add conflict edges between all uses of an instruction
      // This is crucial for instructions like Store that use multiple registers simultaneously
      let used_vregs : Array[Int] = Array::new()
      let used_vfregs : Array[Int] = Array::new()
      for used_op in inst.uses {
        match used_op {
          VReg(v) => used_vregs.push(v)
          VFReg(v) => used_vfregs.push(v)
          _ => ()
        }
      }

      // Add edges between all pairs of used vregs
      for i = 0; i < used_vregs.length(); i = i + 1 {
        for j = i + 1; j < used_vregs.length(); j = j + 1 {
          vreg_graph.add_edge(used_vregs[i], used_vregs[j])
        }
      }
      // Add edges between all pairs of used vfregs
      for i = 0; i < used_vfregs.length(); i = i + 1 {
        for j = i + 1; j < used_vfregs.length(); j = j + 1 {
          vfreg_graph.add_edge(used_vfregs[i], used_vfregs[j])
        }
      }

      // Add conflict edges between defined registers and liveout registers
      // This ensures that a defined register cannot be allocated the same color
      // as any register that is live after the instruction
      let (liveout_vreg_set, liveout_vfreg_set) = spilt_vreg_and_vfreg(
        inst.liveout,
      )
      for def_op in inst.defs {
        match def_op {
          VReg(v) => {
            vreg_graph.add_node(v)
            // Add edge between defined vreg and all liveout vregs
            for liveout_vreg in liveout_vreg_set {
              vreg_graph.add_edge(v, liveout_vreg)
            }
          }
          VFReg(v) => {
            vfreg_graph.add_node(v)
            // Add edge between defined vfreg and all liveout vfregs
            for liveout_vfreg in liveout_vfreg_set {
              vfreg_graph.add_edge(v, liveout_vfreg)
            }
          }
          _ => ()
        }
      }
    }
  }
}

///|
fn spilt_vreg_and_vfreg(opset : Set[Operand]) -> (Set[Int], Set[Int]) {
  let vreg_set = Set::new()
  let vfreg_set = Set::new()
  for op in opset {
    if op is VReg(op) {
      vreg_set.add(op)
    } else if op is VFReg(op) {
      vfreg_set.add(op)
    }
  }
  (vreg_set, vfreg_set)
}

///|
fn live_analysis_for_instruction(inst : Instruction) -> Unit {
  let { defs, uses, livein, liveout, .. } = inst
  // Start with liveout
  liveout.each(o => livein.add(o))
  // Remove defs (registers defined by this instruction are not live before it)
  defs.each(d => if d is (VReg(_) | VFReg(_)) { livein.remove(d) })
  // Add uses (registers used by this instruction must be live before it)
  uses.each(u => if u is (VReg(_) | VFReg(_)) { livein.add(u) })
}

///|
fn update_graph(graph : Graph[Int], live_set : Set[Int]) -> Unit {
  for e in live_set {
    graph.add_node(e)
  }
  for e1 in live_set {
    for e2 in live_set {
      graph.add_edge(e1, e2)
    }
  }
}
