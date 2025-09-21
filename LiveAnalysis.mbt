///|
typealias @deque.Deque

///|
pub fn live_analysis(func : Function) -> (Graph[Int], Graph[Int]) {
  let vreg_graph = Graph::new()
  let vfreg_graph = Graph::new()
  // add param regs to graph
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
/// TODO: Problematic
fn live_analysis_for_basic_blocks(
  bb_queue : Deque[BasicBlock],
  visited_bb_labels : Set[String],
  vreg_graph : Graph[Int],
  vfreg_graph : Graph[Int],
) -> Unit {
  while !bb_queue.is_empty() {
    let head_bb = bb_queue.pop_front().unwrap()
    if head_bb.insts.last() is Some(last_inst) {
      last_inst.liveout.each(o => head_bb.liveout.add(o))
    }

    // Process instructions from back to front
    // The liveout of instruction i is the livein of instruction i+1
    let mut next_livein : Set[Operand] = head_bb.liveout.copy()
    for inst in head_bb.insts.rev_iter() {
      // Set this instruction's liveout to be the next instruction's livein
      inst.liveout.clear()
      next_livein.each(o => inst.liveout.add(o))

      // Compute this instruction's livein
      live_analysis_for_instruction(inst)

      // Build conflict graph based on livein
      let (live_vreg_set, live_fvreg_set) = spilt_vreg_and_vfreg(inst.livein)
      update_graph(vreg_graph, live_vreg_set)
      update_graph(vfreg_graph, live_fvreg_set)

      // Also add defined registers to the graph
      // This ensures that all registers that are defined get allocated
      for def in inst.defs {
        match def {
          VReg(v) => vreg_graph.add_node(v)
          VFReg(v) => vfreg_graph.add_node(v)
          _ => ()
        }
      }

      // Update next_livein for the previous instruction
      next_livein = inst.livein.copy()
    }
    for pred in head_bb.preds {
      head_bb.livein.each(i => pred.liveout.add(i))
    }
    visited_bb_labels.add(head_bb.label)
    for pred in head_bb.preds {
      if pred.successors_label().iter().all(s => visited_bb_labels.contains(s)) &&
        !visited_bb_labels.contains(pred.label) {
        bb_queue.push_back(pred)
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
  liveout.each(o => livein.add(o))
  defs.each(d => if d is (VReg(_) | VFReg(_)) { livein.remove(d) })
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
