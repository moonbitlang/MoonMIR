///|
pub suberror RegAllocError String derive(Show)

///|
pub fn Module::alloc_register(self : Module) -> Unit raise RegAllocError {
  for func in self.functions {
    func.alloc_register()
  }
}

pub fn Function::alloc_register(self : Function) -> Unit raise RegAllocError {
  if false {
    raise RegAllocError("Not implemented yet.")
  }
  // Step 1. Build the interference graph.

  // Step 2. Build the Preference List

  // Step 3. Graph Coloring, get a replacement map

  // Step 4. If replacement map is not empty:
  // rewrite the function, legalize, then back to Step 1,
  // otherwise we're done.
}

