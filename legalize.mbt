///|
pub suberror LegalizeError String derive(Show)

/////|
//pub struct LegalizeConfig {
//  // Maximum Call Registers
//  // If Exceeded, will spill to stack
//  max_num_call_regs : Int
//  // Whether to support select instruction
//  // If false, will lower to branches
//  support_select : Bool
//}

///|
pub fn Module::legalize(self : Self) -> Module raise {
  let new_module = Module::new()
  self.functions.each(func => {
    let legalized_func = legalize_func(func)
    new_module.functions.push(legalized_func)
  })
  new_module
}

///|
pub fn legalize_func(func : Function) -> Function raise {
  let new_func = Function::new(func.name)
  func.params.each(param => new_func.params.push(param))
  for bb in func.body {
    let legalized_bb = legalize_basic_block(bb)
    new_func.body.push(legalized_bb)
  }
  new_func
}

///|
pub fn legalize_basic_block(bb : BasicBlock) -> BasicBlock raise {
  let new_bb = BasicBlock::new(bb.label)
  new_bb.parent = bb.parent
  for inst in bb.insts {
    let legalized_insts = legalize_instruction(inst)
    for lin in legalized_insts {
      new_bb.insts.push(lin)
    }
  }
  new_bb
}

// Phi Elimination

///|
pub fn legalize_instruction(inst : Instruction) -> Array[Instruction] raise {
  if false {
    raise LegalizeError("No legalization rules defined yet")
  }
  [inst]
}
