///|
pub(all) struct Module {
  mut llvm_mod : @IR.Module?
  arch_config : ArchConfig
  functions : Array[Function]
  all_llvm_functions : Map[String, @IR.Function] // includes external functions
  external_functions : Map[String, @IR.Function]
  global_values : Array[GlobalValue]
}

///|
pub fn Module::new(arch_config : ArchConfig) -> Module {
  Module::{
    llvm_mod: None,
    arch_config,
    functions: Array::new(),
    all_llvm_functions: Map::new(),
    external_functions: Map::new(),
    global_values: Array::new(),
  }
}

pub(all) enum ArgPattern {
  I; F
}

pub fn Module::add_function(self: Self, name:String, arg_patterns: Array[ArgPattern]) -> Function {
  let func = Function::new(self, name)
  let { num_arg_regs, num_arg_fregs, ..} = self.arch_config
  let mut areg_cnt = 0
  let mut fareg_cnt = 0
  let mut spill_cnt = 0L
  letrec push_param : (Operand) -> Unit = p => func.params.push(p)
  for arg_pat in arg_patterns {
    match arg_pat {
      I if areg_cnt < num_arg_regs => {
        IRegister(AReg(areg_cnt)) |> push_param
        areg_cnt += 1
      }
      I => {
        let fp_offset = spill_cnt * 8
        Mem(FramePtr, fp_offset) |> push_param
        spill_cnt += 1
      }
      F if fareg_cnt < num_arg_fregs => {
        FRegister(FAReg(fareg_cnt)) |> push_param
        fareg_cnt += 1
      }
      F => {
        let fp_offset = spill_cnt * 8
        Mem(FramePtr, fp_offset) |> push_param
        spill_cnt += 1
      }
    }
  }
  self.functions.push(func)
  func
}

pub fn Module::clear(self: Self) -> Unit {
  self.llvm_mod = None
  self.functions.clear()
  self.all_llvm_functions.clear()
  self.external_functions.clear()
  self.global_values.clear()
}


// -===================-
