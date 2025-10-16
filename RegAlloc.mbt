///|
pub fn Module::alloc_register(self : Module) -> Unit raise MIRError {
  for func in self.functions.values() {
    func.alloc_register()
  }
}

///|
pub fn Function::alloc_register(self : Function) -> Unit raise MIRError {
  // Step 1. Liveness Analysis
  self.live_analysis()
  println("================After liveness analysis=================")
  println(self)
  println("")

  // Step 2. Build the interference graph.
  let interf_graph = self.build_interference_graph()
  println("================After building interference graph=========")
  println(interf_graph)
  println("")

  // Step 2. Build the Preference List
  let pref_list = self.build_preference_list()
  println("================After building preference list===========")
  println(pref_list)
  println("")

  // Step 3. Graph Coloring, get a replacement map
  let (replacement_map, spilled_count) = interf_graph.coloring(pref_list)
  println("================After graph coloring=====================")
  println("Replacement Map:")
  println(replacement_map)
  println("Spilled Count: \{spilled_count}")
  println("")
  if spilled_count != self.spilled_count {
    let extra_spilled = spilled_count - self.spilled_count
    let _ = self.extend_reg_stack(extra_spilled.to_int64() * 8, 8L)

  }
  let need_rewrite = !replacement_map.is_empty() ||
    spilled_count != self.spilled_count

  // Step 4. If replacement map is not empty:
  // rewrite the function, legalize, then back to Step 1,
  // otherwise we're done.
  if need_rewrite {
    self.rewrite_by_replacement_map(replacement_map)
    self.legalize()
    println("================After rewriting by replacement map=======")
    println(self)
    println("")
    self.alloc_register()
  }
}

//
// This Will clear live in and live out.

///|
pub fn Function::rewrite_by_replacement_map(
  self : Function,
  replacement_map : Map[Operand, Operand],
) -> Unit {
  self.body.each(bb => bb.rewrite_by_replacement_map(replacement_map))
}

// This Will clear live in and live out.

///|
pub fn BasicBlock::rewrite_by_replacement_map(
  self : BasicBlock,
  replacement_map : Map[Operand, Operand],
) -> Unit {
  self.insts.each(inst => inst.rewrite_by_replacement_map(replacement_map))
  self.live_in.clear()
  self.live_out.clear()
}

// This Will clear live in and live out.

///|
pub fn Instruction::rewrite_by_replacement_map(
  self : Instruction,
  replacement_map : Map[Operand, Operand],
) -> Unit {
  for i, def in self.defs {
    if replacement_map.get(def) is Some(repl) {
      self.defs[i] = repl
    }
  }
  for i, use_ in self.uses {
    if replacement_map.get(use_) is Some(repl) {
      self.uses[i] = repl
    }
  }
  self.live_in.clear()
  self.live_out.clear()
}
