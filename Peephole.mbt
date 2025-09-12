
pub fn Module::peephole_optimizations(mod: Module) -> Module {
  mod.functions.each(f => peephole_optimizations_for_function(f))
  mod
}

fn peephole_optimizations_for_function(func: Function) -> Unit {
  func.body.each(bb => peephole_optimizations_for_basic_block(bb))
}

fn peephole_optimizations_for_basic_block(bb: BasicBlock) -> Unit {
  let new_insts: Array[Instruction] = Array::new()
  for i, inst in bb.insts {
    // i is the index
    ignore(i)
    match inst {
      // Remove no-op moves
      { opcode: Movb | Movw | Movl | Movq, defs: [dst], uses: [src] } if dst == src => ()
      inst => new_insts.push(inst)
    }
  }
  bb.insts = new_insts
}
