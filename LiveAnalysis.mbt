typealias @deque.Deque as Deque

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
  //let bb_queue = func.terminal_basic_blocks
  let bb_queue : Deque[BasicBlock] = Deque::new()
  let visited_bb_labels : Set[String] = Set::new()
  live_analysis_for_basic_blocks(
    bb_queue, visited_bb_labels, vreg_graph, vfreg_graph
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
    for inst in head_bb.insts.rev_iter() {
      live_analysis_for_instruction(inst)
      let (live_vreg_set, live_fvreg_set) = spilt_vreg_and_vfreg(inst.livein)
      update_graph(vreg_graph, live_vreg_set)
      update_graph(vfreg_graph, live_fvreg_set)
    }
    for pred in head_bb.preds {
      head_bb.livein.each(i => pred.liveout.add(i))
    }
    visited_bb_labels.add(head_bb.label)
    for pred in head_bb.preds {
        if pred.successors_label()
               .iter()
               .all(s => visited_bb_labels.contains(s)) &&
               !visited_bb_labels.contains(pred.label) {
        bb_queue.push_back(pred)
      }
    }
  }
}

fn spilt_vreg_and_vfreg(opset: Set[Operand]) -> (Set[Int], Set[Int]) {
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
fn live_analysis_for_instruction(
  inst : Instruction,
) -> Unit {
  let { defs, uses, livein, liveout,.. } = inst
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
