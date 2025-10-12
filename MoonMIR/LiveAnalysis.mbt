///|
typealias @deque.Deque

pub fn Function::live_analysis(self: Self) -> Unit {
  let bb_queue : Deque[BasicBlock] = Deque::new()
  self.terminal_blocks.each(bb => bb_queue.push_back(bb))
  while !bb_queue.is_empty() {
    let bb = bb_queue.pop_front().unwrap()
    let bb_is_changed = bb.live_analysis()
    if bb_is_changed {
      bb.preds
        .filter(pred_bb => !bb_queue.contains(pred_bb))
        .each(pred_bb => bb_queue.push_back(pred_bb))
    }
  }
}

//return if is changed
pub fn BasicBlock::live_analysis(self: Self) -> Bool {
  // Step 1. Compute live_out as the union of live_in of all successors

  // Step 2. traverse instructions in reverse order
  // to compute live_in and live_out for each instruction

  // Step 3. Compute live_in
  false
}
