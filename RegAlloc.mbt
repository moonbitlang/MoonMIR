///|
pub suberror RegAllocError String derive(Show)

///|
pub fn Module::alloc_register(self : Module) -> Module raise RegAllocError {
  if self.reg_allocated {
    raise RegAllocError(
      "Register allocation has already been run on this module.",
    )
  }
  for func in self.functions {
    func.alloc_register()
  }
  self
}

///|
pub fn Function::alloc_register(f : Function) -> Unit raise RegAllocError {
  if f.reg_allocated {
    raise RegAllocError(
      "Register allocation has already been run on this function.",
    )
  }
  let { max_num_reg, max_num_freg, .. } = f.getArchConfig()

  // Live Analysis
  let (vreg_graph, vfreg_graph) = live_analysis(f)

  // Graph Coloring
  let (vreg_color_map, max_vreg_color) = vreg_graph.coloring()
  let (vfreg_color_map, max_vfreg_color) = vfreg_graph.coloring()

  // Adjust Stack Size for Spilled Variables
  let ori_stack_size = f.stack_size
  let vreg_spilled_count = if max_vreg_color > max_num_reg {
    max_vreg_color - max_num_reg
  } else {
    0
  }
  let vfreg_spilled_count = if max_vfreg_color > max_num_freg {
    max_vfreg_color - max_num_freg
  } else {
    0
  }
  f.stack_size += ((vreg_spilled_count + vfreg_spilled_count) * 8).to_int64() // Assume 8 bytes per spill

  // Assign Colors to Operands
  let vreg_operand_map = assign_vreg_color_to_operand(
    ori_stack_size~,
    vreg_color_map~,
    max_num_reg~,
  )
  let vfreg_operand_map = assign_vfreg_color_to_operand(
    ori_stack_size~,
    vfreg_color_map~,
    max_num_freg~,
  )

  // Rewrite Instructions
  for bb in f.body {
    for inst in bb.insts {
      //rewrite_instruction(inst, vreg_color_map~, vfreg_color_map~, max_num_reg~, max_num_freg~, stack_vreg_map~, stack_vfreg_map~);
      rewrite_instruction(inst, vreg_operand_map~, vfreg_operand_map~)
    }
  }

  // Rewrite function parameters using the same color mapping
  for i, param in f.params {
    match param {
      VReg(v) =>
        if vreg_operand_map.contains(v) {
          f.params[i] = vreg_operand_map[v]
        }
      VFReg(v) =>
        if vfreg_operand_map.contains(v) {
          f.params[i] = vfreg_operand_map[v]
        }
      _ => ()
    }
  }
}

///|
fn assign_vreg_color_to_operand(
  ori_stack_size~ : Int64,
  vreg_color_map~ : Map[Int, Int],
  max_num_reg~ : Int,
) -> Map[Int, Operand] {
  let operand_map : Map[Int, Operand] = Map::new()
  for pair in vreg_color_map {
    let (vreg, color) = pair
    if color < max_num_reg {
      operand_map.set(vreg, Reg(color))
    } else {
      let offset = ori_stack_size +
        (color.to_int64() - max_num_reg.to_int64()) * 8 // Assume 8 bytes per spill
      operand_map.set(vreg, Mem(StackPtr, offset))
    }
  }
  operand_map
}

///|
fn assign_vfreg_color_to_operand(
  ori_stack_size~ : Int64,
  vfreg_color_map~ : Map[Int, Int],
  max_num_freg~ : Int,
) -> Map[Int, Operand] {
  let operand_map : Map[Int, Operand] = Map::new()
  for pair in vfreg_color_map {
    let (vfreg, color) = pair
    if color < max_num_freg {
      operand_map.set(vfreg, FReg(color))
    } else {
      let offset = ori_stack_size +
        (color.to_int64() - max_num_freg.to_int64()) * 8 // Assume 8 bytes per spill
      operand_map.set(vfreg, Mem(StackPtr, offset))
    }
  }
  operand_map
}

///|
pub fn rewrite_instruction(
  inst : Instruction,
  vreg_operand_map~ : Map[Int, Operand],
  vfreg_operand_map~ : Map[Int, Operand],
) -> Unit raise RegAllocError {
  let { defs, uses, .. } = inst
  for i, op in defs {
    match op {
      VReg(v) => {
        guard vreg_operand_map.get(v) is Some(operand) else {
          raise RegAllocError("No operand found for vreg \{v}")
        }
        defs[i] = operand
      }
      VFReg(v) => {
        guard vfreg_operand_map.get(v) is Some(operand) else {
          raise RegAllocError("No operand found for vfreg \{v}")
        }
        defs[i] = operand
      }
      _ => ()
    }
  }
  for i, op in uses {
    match op {
      VReg(v) => {
        guard vreg_operand_map.get(v) is Some(operand) else {
          raise RegAllocError("No operand found for vreg \{v}")
        }
        uses[i] = operand
      }
      VFReg(v) => {
        guard vfreg_operand_map.get(v) is Some(operand) else {
          raise RegAllocError("No operand found for vfreg \{v}")
        }
        uses[i] = operand
      }
      _ => ()
    }
  }
}
