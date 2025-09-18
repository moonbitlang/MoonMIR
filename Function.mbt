///|
pub(all) struct Function {
  name : String
  params : Array[Operand]
  body : Array[BasicBlock]
  mut stack_size : Int
}

///|
pub fn Function::new(name : String) -> Function {
  Function::{ name, params: [], body: [], stack_size: 0 }
}

///|
pub impl Show for Function with output(self, logger) {
  logger.write_string("func \{self.name}(")
  let pstr = self.params.map(p => p.to_string()).join(", ")
  logger.write_string(pstr)
  logger.write_string(") {\n")
  for bb in self.body {
    logger.write_string(bb.to_string())
  }
  logger.write_string("}\n")
}


