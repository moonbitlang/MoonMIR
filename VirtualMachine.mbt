
pub enum VMValue {
  Int(Int)
  Double(Double)
}

pub suberror VMError {
  // Errors related to unreasonable operations,
  // for example, call a unknown function, or use
  // a undefined register.
  IRError(String)

  // Errors related to runtime issues,
  // for example, divide by zero, or overflow.
  RuntimeError(String)
} derive(Show)


pub struct VirtualMachine {
}

pub fn VirtualMachine::eval_module(self: Self, mod: Module) -> Unit raise VMError {
  ...
}

pub fn VirtualMachine::eval_function(self: Self, func: Function, args: Array[VMValue]) -> VMValue raise VMError {
  ...
}
