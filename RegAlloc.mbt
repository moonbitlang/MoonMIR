
pub fn Module::reg_alloc(self: Module, max_num_reg~: Int, max_num_freg~: Int) -> Module {
  for func in self.functions {
    reg_alloc_for_function(func, max_num_reg~, max_num_freg~);
  }
  self
}

// TODO: Unimplemented
pub fn reg_alloc_for_function(f: Function, max_num_reg~: Int, max_num_freg~: Int) -> Unit {
  // Live Analysis

  // Build Interference Graph

  // Graph Coloring

  // Rewrite Instructions
  for bb in f.body {
    for inst in bb.insts {
      rewrite_instruction(inst, max_num_reg~, max_num_freg~);
    }
  }
}

pub fn rewrite_instruction(inst: Instruction, max_num_reg~: Int, max_num_freg~: Int) -> Unit {
  let {defs, uses, ..} = inst;
  for i, op in defs {
    match op {
      VReg(v) if v < max_num_reg => defs[i] = Reg(v)
      FReg(v) if v < max_num_freg => defs[i] = FReg(v)
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
