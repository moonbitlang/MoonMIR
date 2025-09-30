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

///|
pub(all) enum ArgPattern {
  I
  F
}

///|
///
/// ```mbt
/// let mod = Module::new(ArchConfig::riscv64())
/// let func = mod.add_function("add", [I, I])
/// let entry_bb = func.append_basic_block("entry")
/// let builder = IRBuilder::new(func, entry_bb)
///
/// let a0 = func.get_param(0).unwrap()
/// let a1 = func.get_param(1).unwrap()
/// guard a0 is IRegister(a0)
/// guard a1 is IRegister(a1)
///
/// builder.build_ibinary(Add, 32, dst = AReg(0), src1 = a0, src2 = a1)
/// |> BasicBlock::push(entry_bb, _)
///
/// builder.build_ret()
/// |> BasicBlock::push(entry_bb, _)
///
/// let expected = 
///   #|func add(a0, a1) {
///   #|entry:
///   #|  a0 = add.i32 a0, a1
///   #|  ret
///   #|}
///   #|
/// inspect(func, content=expected)
/// ```
pub fn Module::add_function(
  self : Self,
  name : String,
  arg_patterns : Array[ArgPattern],
) -> Function {
  let func = Function::new(self, name)
  if arg_patterns.is_empty() {
    return func
  }
  func.set_params_by_patterns(arg_patterns)
  self.functions.push(func)
  func
}

///|
///
/// ```mbt
/// let mod = Module::new(ArchConfig::riscv64())
/// let content = #|Hello, World!\n
/// let gv = mod.add_global_string(label="msg", content~)
///
/// let expected = 
///   #|global msg {
///   #|  "Hello, World!\n"
///   #|}
///   #|
/// inspect(gv, content=expected)
/// ```
pub fn Module::add_global_string(
  self : Self,
  label~ : String,
  content~ : String,
) -> GlobalValue {
  let gv = GlobalValue::{
    label,
    content: GlobalValueContent::String(content),
    mod: self,
    llvm_gv: None,
  }
  self.global_values.push(gv)
  gv
}

///|
///
/// ```mbt
/// let mod = Module::new(ArchConfig::riscv64())
/// let gv = mod.add_global_zero_data("buffer", 64)
/// 
/// let expected =
///  #|global buffer {
///  #|  .zero 64
///  #|}
///  #|
/// inspect(gv, content=expected)
/// ```
pub fn Module::add_global_zero_data(
  self : Self,
  label : String,
  size : UInt,
) -> GlobalValue {
  let gv = GlobalValue::{
    label,
    content: GlobalValueContent::Zero(size),
    mod: self,
    llvm_gv: None,
  }
  self.global_values.push(gv)
  gv
}

///|
///
/// ```mbt
/// let mod = Module::new(ArchConfig::riscv64())
/// let data : Array[GlobalValueData] = [
///   Quad(0x1122334455667788),
///   Word(0x99AABBCC),
///   Half(0xDDEE),
///   Byte(0xFF),
/// ]
/// let gv = mod.add_global_data("data", data)
///
/// let expected =
///   #|global data {
///   #|  .quad 1234605616436508552
///   #|  .word 2578103244
///   #|  .half 56814
///   #|  .byte 255
///   #|}
///   #|
/// inspect(gv, content=expected)
/// ```
pub fn Module::add_global_data(
  self : Self,
  label : String,
  data : Array[GlobalValueData],
) -> GlobalValue {
  let gv = GlobalValue::{
    label,
    content: GlobalValueContent::Data(data),
    mod: self,
    llvm_gv: None,
  }
  self.global_values.push(gv)
  gv
}

///|
pub fn Module::clear(self : Self) -> Unit {
  self.llvm_mod = None
  self.functions.clear()
  self.all_llvm_functions.clear()
  self.external_functions.clear()
  self.global_values.clear()
}

// -===================-
