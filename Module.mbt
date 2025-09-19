///|
pub(all) struct Module {
  llvm_mod : @IR.Module
  arch_config : ArchConfig
  functions : Array[Function]
  all_llvm_functions : Map[String, @IR.Function] // includes external functions
  external_functions : Map[String, @IR.Function]
  // globals: Array[GlobalVariable] (not implemented yet)

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
    ir_translated: false,
    legalized: false,
    reg_allocated: false,
  }
}

///|
pub fn Module::run_ir_translation(self : Self) -> Unit raise IRTranslateError {
  if self.ir_translated {
    raise IRTranslateError(
      "IR translation has already been run on this module.",
    )
  }
  for func_pair in self.llvm_mod.functions {
    let (_, func) = func_pair
    if func.isDeclaration() {
      self.external_functions.set(func.getName().unwrap(), func)
    } else {
      let f = Function::new(self, func)
      f.run_ir_translation()
      self.functions.push(f)
    }
  }
  self.ir_translated = true
}

///|
pub impl Show for Module with output(self, logger) {
  for func in self.functions {
    logger.write_string(func.to_string())
    logger.write_string("\n")
  }
}
