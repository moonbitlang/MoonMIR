
pub fn Module::reg_alloc(self: Module) -> Module {
  for func in self.functions {
    reg_alloc_for_function(func);
  }
  self
}

pub fn reg_alloc_for_function(f: Function) -> Unit {
  // Live Analysis

  // Build Interference Graph

  // Graph Coloring

  // Rewrite Instructions
  for bb in f.body {
    for inst in bb.insts {
      rewrite_instruction(inst);
    }
  }
}

pub fn rewrite_instruction(inst: Instruction) -> Unit {
  let {defs, uses, ..} = inst;
  for i, op in defs {
    match op {
      VReg(0..<17 as v) => defs[i] = Reg(v)
      FReg(0..<11 as v) => defs[i] = FReg(v)
      _ => ()
    }
  }

  for i, op in uses {
    match op {
      VReg(0..<17 as v) => uses[i] = Reg(v)
      FReg(0..<11 as v) => uses[i] = FReg(v)
      _ => ()
    }
  }
}
