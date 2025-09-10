

// Graph Coloring Algorithm
pub struct Graph[T] { // T Must Be Hashable and Equatable
  nodes: Set[T]
  edges: Map[T, Set[T]]
}

pub fn[T] Graph::new() -> Graph[T] {
  Graph::{
    nodes: Set::new(),
    edges: Map::new()
  }
}

pub fn[T: Hash+Eq] Graph::add_node(self: Graph[T], node: T) -> Unit {
  if !self.edges.contains(node) {
    self.nodes.add(node);
    self.edges[node] = Set::new();
  }
}

pub fn[T: Hash+Eq] Graph::add_edge(self: Graph[T], node1: T, node2: T) -> Unit {
  if node1 == node2 {
    return ;
  }
  if !self.nodes.contains(node1) {
    self.add_node(node1);
  }
  if !self.nodes.contains(node2) {
    self.add_node(node2);
  }
  self.edges[node1].add(node2);
  self.edges[node2].add(node1);
}

pub fn[T: Hash + Eq] Graph::coloring(self: Graph[T]) -> Map[T, Int] {
  let colors: Map[T, Int] = Map::new();
  let nodes: Set[T] = self.nodes.copy();

  for node in nodes {
    let neighbor_colors: Set[Int] = Set::new();
    for neighbor in self.edges[node] {
      if colors.contains(neighbor) {
        neighbor_colors.add(colors[neighbor]);
      }
    }

    let mut color = 0;
    while neighbor_colors.contains(color) {
      color += 1;
    }
    colors[node] = color;
  }

  colors
}
