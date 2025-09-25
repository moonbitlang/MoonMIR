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

///|
pub fn Module::run_ir_translation(self : Self) -> Unit raise IRTranslateError {
  if self.ir_translated {
    raise IRTranslateError(
      "IR translation has already been run on this module.",
    )
  }
  for gv_pair in self.llvm_mod.globals {
    let (_, gv) = gv_pair
    match gv.asGlobalValueEnum() {
      Function(_) => () // skip functions for now
      _ => {
        let g = GlobalValue::new(self, gv)
        self.global_values.push(g)
      }
    }
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
  for gv in self.global_values {
    logger.write_string(gv.to_string())
    logger.write_string("\n")
  }
  for func in self.functions {
    logger.write_string(func.to_string())
    logger.write_string("\n")
  }
}
