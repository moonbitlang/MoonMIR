///|
typealias @deque.Deque

///|
///
/// Perform live variable analysis on the function.
///
/// ```mbt
/// let code = 
///   #|fn foo(x: Int, y: Int) -> Int {
///   #|  let a = x + y;
///   #|  let b = x - y;
///   #|  let c = a * b;
///   #|  let d = a / b;
///   #|  let e = c % d;
///   #|  e
///   #|}
///
/// let llvm_mod = @TinyMoonBit.compile(code)
///
/// // IRTranslate
/// let rv64 = ArchConfig::riscv64()
/// let mir_mod = Module::new(rv64)
/// mir_mod.translate_llvm_module(llvm_mod)
/// let mir_func = mir_mod.get_function("foo").unwrap()
/// mir_func.live_analysis()
///
/// let expected = 
///    #|func foo(a0, a1) {
///    #|entry:                       ; live in: a1, a0
///    #|  v0 = move.i64 a0           # live in: a1, a0
///    #|  v1 = move.i64 a1           # live in: v0, a1
///    #|  v2 = add.i32 v0, v1        # live in: v0, v1
///    #|  v3 = sub.i32 v0, v1        # live in: v2, v0, v1
///    #|  v4 = mul.i32 v2, v3        # live in: v2, v3
///    #|  v5 = div.i32 v2, v3        # live in: v4, v2, v3
///    #|  v6 = rem.i32 v4, v5        # live in: v4, v5
///    #|  a0 = move.i64 v6           # live in: v6
///    #|  ret
///    #|}
///    #|
///
/// inspect(mir_func, content=expected)
/// ```
pub fn Function::live_analysis(self : Self) -> Unit {
  let bb_queue : Deque[BasicBlock] = Deque::new()
  self.terminal_blocks.each(bb => bb_queue.push_back(bb))
  fn append_preds(bb : BasicBlock) {
    bb.preds
    .filter(pred_bb => !bb_queue.contains(pred_bb))
    .each(pred_bb => bb_queue.push_back(pred_bb))
  }

  while !bb_queue.is_empty() {
    let bb = bb_queue.pop_front().unwrap()
    // If the basic block does not use any registers, skip it.
    if !bb.utilize_any_register() {
      append_preds(bb)
      continue
    }
    let bb_is_changed = bb.live_analysis()
    if bb_is_changed {
      append_preds(bb)
    }
  }
}

///|
///
/// return if is changed
pub fn BasicBlock::live_analysis(self : Self) -> Bool {
  let mut is_changed = false

  // Step 1. Compute live_out as the union of live_in of all successors
  let mut live_out = self.compute_live_out_from_succs()
  is_changed = self.update_live_out(live_out) || is_changed

  // Step 2. traverse instructions in reverse order
  // to compute live_in and live_out for each instruction
  for inst in self.insts.rev_iter() {
    is_changed = inst.update_live_out(live_out) || is_changed
    is_changed = inst.live_analysis() || is_changed
    live_out = inst.live_in.copy()
  }

  // Step 3. Compute live_in from the first instruction
  if !self.insts.is_empty() {
    let first_inst = self.insts[0]
    is_changed = self.update_live_in(first_inst.live_in) || is_changed
  }
  is_changed
}

///|
///
pub fn Instruction::live_analysis(self : Self) -> Bool {
  let { defs, uses, .. } = self
  let live_in : Set[Operand] = self.live_out.copy()
  // Remove defs from live_in
  defs.each(d => if d is (IRegister(_) | FRegister(_)) { live_in.remove(d) })
  // Add uses to live_in
  uses.each(u => if u is (IRegister(_) | FRegister(_)) { live_in.add(u) })

  // update_live_in returns true if changed
  let is_changed = self.update_live_in(live_in)
  is_changed
}

///|
fn BasicBlock::utilize_any_register(self : Self) -> Bool {
  self.insts.iter().any(inst => inst.def_and_use_any_register())
}

///|
fn Instruction::def_and_use_any_register(self : Self) -> Bool {
  self.defs.iter().any(d => d is (IRegister(_) | FRegister(_))) ||
  self.uses.iter().any(u => u is (IRegister(_) | FRegister(_)))
}
