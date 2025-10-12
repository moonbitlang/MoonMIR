pub struct InterferenceGpaph {
  nodes: Set[Operand]
  edges: Map[Operand, Set[Operand]]
}

pub fn InterferenceGpaph::new() -> InterferenceGpaph {
  InterferenceGpaph::{ nodes: Set::new(), edges: Map::new() }
}

pub fn InterferenceGpaph::add_node(self : InterferenceGpaph, node : Operand) -> Unit {
  // No need to check if nodes contains node.
  self.nodes.add(node)
  if !self.edges.contains(node) {
    self.edges[node] = Set::new()
  }
}

pub fn InterferenceGpaph::add_edge(
  self : InterferenceGpaph,
  node1 : Operand,
  node2 : Operand,
) -> Unit {
  if node1 == node2 {
    return
  }
  // No need to check if nodes contains node1 or node2.
  self..add_node(node1) .. add_node(node2)
  self.edges[node1].add(node2)
  self.edges[node2].add(node1)
}

