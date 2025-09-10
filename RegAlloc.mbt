
pub suberror RegAllocError String derive(Show)

pub fn Module::reg_alloc(
  self: Module,
  max_num_reg~: Int,
  max_num_freg~: Int
) -> Module raise RegAllocError {
  for func in self.functions {
    reg_alloc_for_function(func, max_num_reg~, max_num_freg~);
  }
  self
}

// TODO: Unimplemented
pub fn reg_alloc_for_function(
  f: Function,
  max_num_reg~: Int,
  max_num_freg~: Int
) -> Unit raise RegAllocError {
  // Live Analysis
  let (vreg_graph, vfreg_graph) = live_analysis(f);

  // Graph Coloring
  let (vreg_color_map, max_vreg_color) = vreg_graph.coloring()
  let (vfreg_color_map, max_vfreg_color) = vfreg_graph.coloring()

  // Spill
  let (stack_vreg_map, stack_vfreg_map) = spill(
    f, vreg_color_map~, max_vreg_color~, max_num_reg~,
    vfreg_color_map~, max_vfreg_color~, max_num_freg~);

  // Rewrite Instructions
  for bb in f.body {
    for inst in bb.insts {
      rewrite_instruction(inst, vreg_color_map~, vfreg_color_map~, max_num_reg~, max_num_freg~, stack_vreg_map~, stack_vfreg_map~);
    }
  }
}

pub fn spill(
  f: Function,
  vreg_color_map~: Map[Int, Int],
  max_vreg_color~: Int,
  max_num_reg~: Int,
  vfreg_color_map~: Map[Int, Int],
  max_vfreg_color~: Int,
  max_num_freg~: Int
) -> (Map[Int, Int], Map[Int, Int]) {
  let num_vreg_on_stack = if max_vreg_color > max_num_reg {
    max_vreg_color - max_num_reg
  } else { 0 };
  let num_vfreg_on_stack = if max_vfreg_color > max_num_freg {
    max_vfreg_color - max_num_freg
  } else { 0 };
  let total_stack_size = (num_vreg_on_stack + num_vfreg_on_stack) * 8; // Assume 8 bytes per spill
  let ori_stack_size = f.stack_size;
  f.stack_size += total_stack_size;

  let stack_vreg_map : Map[Int, Int] = Map::new();
  let stack_vfreg_map : Map[Int, Int] = Map::new();
  for pair in vreg_color_map {
    let (vreg, color) = pair
    if color >= max_num_reg {
      let offset = ori_stack_size + (color - max_num_reg) * 8;
      stack_vreg_map.set(vreg, offset);
    }
  }
  for pair in vfreg_color_map {
    let (vfreg, color) = pair
    if color >= max_num_freg {
      let offset = ori_stack_size + (color - max_num_freg) * 8;
      stack_vfreg_map.set(vfreg, offset);
    }
  }
  (stack_vreg_map, stack_vfreg_map)
}

pub fn rewrite_instruction(
  inst: Instruction,
  max_num_reg~: Int,
  max_num_freg~: Int,
  vreg_color_map~: Map[Int, Int],
  vfreg_color_map~: Map[Int, Int],
  stack_vreg_map~: Map[Int, Int],
  stack_vfreg_map~: Map[Int, Int]
) -> Unit raise RegAllocError {
  let {defs, uses, ..} = inst;
  for i, op in defs {
    match op {
      VReg(v) => {
        guard vreg_color_map.get(v) is Some(v) else {
          raise RegAllocError("No color found for vreg \{v}"); 
        }
        if v < max_num_reg {
          defs[i] = Reg(v);
        } else {
          let offset = stack_vreg_map.get(v).unwrap_or_else(() => raise RegAllocError("No stack slot found for spilled vreg \{v}"));
          defs[i] = Mem(StackTop, offset);
        }
      }
      VFReg(v) => {
        guard vfreg_color_map.get(v) is Some(v) else {
          raise RegAllocError("No color found for vfreg \{v}"); 
        }
        if v < max_num_freg {
          defs[i] = FReg(v);
        } else {
          let offset = stack_vfreg_map.get(v).unwrap_or_else(() => raise RegAllocError("No stack slot found for spilled vfreg \{v}"));
          defs[i] = Mem(StackTop, offset);
        }
      }
      _ => ()
    }
  }

  for i, op in uses {
    match op {
      VReg(v) if v < max_num_reg  => uses[i] = Reg(v)
      FReg(v) if v < max_num_freg  => uses[i] = FReg(v)
      _ => ()
    }
  }
}
