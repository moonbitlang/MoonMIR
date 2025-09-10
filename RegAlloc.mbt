
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
  let vreg_color_map = vreg_graph.coloring()
  let vfreg_color_map = vfreg_graph.coloring()

  // Rewrite Instructions
  for bb in f.body {
    for inst in bb.insts {
      rewrite_instruction(inst, vreg_color_map~, vfreg_color_map~, max_num_reg~, max_num_freg~);
    }
  }
}

pub fn rewrite_instruction(
  inst: Instruction,
  max_num_reg~: Int,
  max_num_freg~: Int,
  vreg_color_map~: Map[Int, Int],
  vfreg_color_map~: Map[Int, Int]
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
          raise RegAllocError("Too many vregs, spill not implemented");
        }
      }
      VFReg(v) => {
        guard vfreg_color_map.get(v) is Some(v) else {
          raise RegAllocError("No color found for vfreg \{v}"); 
        }
        if v < max_num_freg {
          defs[i] = FReg(v);
        } else {
          raise RegAllocError("Too many vfregs, spill not implemented");
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
