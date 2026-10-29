///|
test "preferred colors avoid the fallback for integer and floating registers" {
  let graph = InterferenceGraph::new(ArchConfig::debug(), 0)
  let int_node = IRegister(VReg(0))
  let fp_node = FRegister(VFReg(0))
  graph..add_node(int_node).add_node(fp_node)
  let int_colors : Deque[Operand] = Deque([IRegister(AReg(3))])
  let fp_colors : Deque[Operand] = Deque([FRegister(FAReg(3))])
  let preferences : Map[Operand, Deque[Operand]] = Map([
    (int_node, int_colors),
    (fp_node, fp_colors),
  ])
  let (colors, spills) = graph.coloring(preferences)
  assert_true(colors[int_node] == IRegister(AReg(3)))
  assert_true(colors[fp_node] == FRegister(FAReg(3)))
  assert_eq(spills, 0)
}

///|
test "missing preferred colors fall back to an available register" {
  let graph = InterferenceGraph::new(ArchConfig::debug(), 0)
  let int_node = IRegister(VReg(0))
  let fp_node = FRegister(VFReg(0))
  graph..add_node(int_node).add_node(fp_node)
  graph.available_int_colors.clear()
  graph.available_int_colors.add(IRegister(AReg(0)))
  graph.available_fp_colors.clear()
  graph.available_fp_colors.add(FRegister(FAReg(0)))
  let (colors, spills) = graph.coloring(Map([]))
  assert_true(colors[int_node] == IRegister(AReg(0)))
  assert_true(colors[fp_node] == FRegister(FAReg(0)))
  assert_eq(spills, 0)
}

///|
test "interfering physical registers force distinct spill slots" {
  let graph = InterferenceGraph::new(ArchConfig::debug(), 0)
  let int_node = IRegister(VReg(0))
  let fp_node = FRegister(VFReg(0))
  graph.available_int_colors.clear()
  graph.available_int_colors.add(IRegister(AReg(0)))
  graph.available_fp_colors.clear()
  graph.available_fp_colors.add(FRegister(FAReg(0)))
  graph.add_edge(int_node, IRegister(AReg(0)))
  graph.add_edge(fp_node, FRegister(FAReg(0)))
  let (colors, spills) = graph.coloring(Map([]))
  assert_true(colors[int_node] == Mem(FramePtrPrim, 0L))
  assert_true(colors[fp_node] == Mem(FramePtrPrim, 8L))
  assert_eq(spills, 2)
}
