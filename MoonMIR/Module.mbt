///|
pub(all) struct Module {
  llvm_mod : @IR.Module
  arch_config : ArchConfig
  functions : Array[Function]
  all_llvm_functions : Map[String, @IR.Function] // includes external functions
  external_functions : Map[String, @IR.Function]
  global_values : Array[GlobalValue]

  // Phase tracking
  mut ir_translated : Bool
  mut legalized : Bool
  mut reg_allocated : Bool
}

///|
pub fn Module::new(llvm_mod : @IR.Module, arch_config : ArchConfig) -> Module {
  Module::{
    llvm_mod,
    arch_config,
    functions: Array::new(),
    all_llvm_functions: llvm_mod.functions,
    external_functions: Map::new(),
    global_values: Array::new(),
    ir_translated: false,
    legalized: false,
    reg_allocated: false,
  }
}
