///|
pub(all) struct Module {
  functions : Array[Function]
  // globals: Array[GlobalVariable] (not implemented yet)
}

///|
pub fn Module::new() -> Module {
  Module::{ functions: Array::new() }
}

///|
pub impl Show for Module with output(self, logger) {
  for func in self.functions {
    logger.write_string(func.to_string())
    logger.write_string("\n")
  }
}
