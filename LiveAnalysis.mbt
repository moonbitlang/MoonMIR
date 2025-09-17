///|
pub fn live_analysis(func : Function) -> (Graph[Int], Graph[Int]) {
  let vreg_graph = Graph::new()
  let vfreg_graph = Graph::new()
  if func.body.is_empty() {
    return (vreg_graph, vfreg_graph)
  }
  let last_bb = func.body.last().unwrap()
  let live_vreg_set : Set[Int] = Set::new()
  let live_fvreg_set : Set[Int] = Set::new()
  live_analysis_for_basic_block(
    last_bb, vreg_graph, vfreg_graph, live_vreg_set, live_fvreg_set,
  )
  (vreg_graph, vfreg_graph)
}

///|
fn live_analysis_for_basic_block(
  bb : BasicBlock,
  vreg_graph : Graph[Int],
  vfreg_graph : Graph[Int],
  live_vreg_set : Set[Int],
  live_fvreg_set : Set[Int],
) -> Unit {
  for inst in bb.insts.rev_iter() {
    live_analysis_for_vreg_instruction(inst, live_vreg_set)
    live_analysis_for_fvreg_instruction(inst, live_fvreg_set)
    update_graph(vreg_graph, live_vreg_set)
    update_graph(vfreg_graph, live_fvreg_set)
  }
  for pred in bb.preds {
    live_analysis_for_basic_block(
      pred, vreg_graph, vreg_graph, live_vreg_set, live_fvreg_set,
    )
  }
}

///|
fn live_analysis_for_vreg_instruction(
  inst : Instruction,
  live_vreg_set : Set[Int],
) -> Unit {
  let { defs, uses, .. } = inst
  defs.each(d => if d is VReg(d) { live_vreg_set.remove(d) })
  uses.each(u => if u is VReg(u) { live_vreg_set.add(u) })
}

///|
fn live_analysis_for_fvreg_instruction(
  inst : Instruction,
  live_fvreg_set : Set[Int],
) -> Unit {
  let { defs, uses, .. } = inst
  defs.each(d => if d is VFReg(d) { live_fvreg_set.remove(d) })
  uses.each(u => if u is VFReg(u) { live_fvreg_set.add(u) })
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
