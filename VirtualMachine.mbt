
pub enum VMValue {
  Int(Int)
  Double(Double)
  Void
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
  external_functions: Map[String, (Array[VMValue]) -> VMValue raise VMError] // only need function names
}

pub fn VirtualMachine::new() -> VirtualMachine {
  fn print_int(args: Array[VMValue]) -> VMValue raise VMError {
    if args.length() < 1 {
      raise VMError::RuntimeError("print_int expects at least 1 argument");
    }
    match args[0] {
      VMValue::Int(i) => println(i)
      _ => raise VMError::RuntimeError("print_int expects an integer argument")
    }
    VMValue::Void
  }
  let external_functions: Map[String, (Array[VMValue]) -> VMValue raise VMError] = {
    "print_int" : print_int
  };
  VirtualMachine::{ external_functions }
}

pub fn VirtualMachine::eval_module(self: Self, mod: Module) -> Unit raise VMError {
  ...
}

pub fn VirtualMachine::eval_function(self: Self, func: Function, args: Array[VMValue]) -> VMValue raise VMError {
  ...
}
