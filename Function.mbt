///|
pub(all) struct Function {
  mod: Module

  // Function Attributes
  name : String
  params : Array[Operand]
  body : Array[BasicBlock]
  mut stack_size : Int64

  // LLVM
  llvm_func: @IR.Function

  // Value Map
  value_map : Map[&LLVMValue, Operand]
  bbmap : Map[String, BasicBlock] // Map from label to BasicBlock
  mut vreg_cnt : Int
  mut vfreg_cnt : Int

  // Some Infos
  phi_insts: Array[Instruction]

  // phase tracking
  mut ir_translated : Bool
  mut legalized : Bool
  mut reg_allocated : Bool
}

fn Function::new(mod: Module, llvm_func: @IR.Function) -> Function {
  Function::{
    mod,
    name: llvm_func.getName().unwrap(),
    params: Array::new(),
    body: Array::new(),
    stack_size: 0,
    llvm_func,
    value_map: Map::new(),
    bbmap: Map::new(),
    vreg_cnt: 0,
    vfreg_cnt: 0,
    phi_insts: Array::new(),
    ir_translated: false,
    legalized: false,
    reg_allocated: false,
  }
}

pub fn Function::getArchConfig(self: Self) -> ArchConfig {
  self.mod.arch_config
}

///| For Quick Debugging
pub fn Function::from_llvm_function(llvm_func: @IR.Function, arch_config: ArchConfig) -> Function raise IRTranslateError {
  let llvm_mod = llvm_func.getModule()
  let mod = Module::new(llvm_mod, arch_config)
  let func = Function::new(mod, llvm_func)
  func.run_ir_translation()
  func
}

pub fn Function::run_ir_translation(self: Self) -> Unit raise IRTranslateError {
  if self.ir_translated {
    raise IRTranslateError("Function \{self.name} has already been translated.")
  }
  // Setp 1: Arrign virtual registers for parameters.
  // It will according to the calling convention rules
  // assign vreg/vfreg/mem for each parameter.
  self.assign_vreg_for_params()

  // Step 2 - 1: Translate each basic block.
  // Reverse Post-Order Traversal Basic Blocks first
  let sorted_bbs = self.sort_llvm_basick_block()

  for i, llvm_bb in sorted_bbs {
    let label = if llvm_bb.getName() is Some(n) { n } else { "L\{i}"}
    let machine_bb = BasicBlock::new(self, llvm_bb, label)
    self.body.push(machine_bb)
    self.value_map.set(llvm_bb, Label(label))
    self.bbmap.set(label, machine_bb)
  }
  
  // Step 2 - 2: Translate each basic block.
  for machine_bb in self.body {
    machine_bb.run_ir_translation()
  }
  self.phi_elimination()

  self.ir_translated = true
}

///|
fn Function::assign_vreg_for_params(self: Self) -> Unit {
  let { max_num_call_regs, max_num_call_fregs, .. } = self.mod.arch_config
  for i, arg in self.llvm_func.arguments {
    if arg.getType().isIEEELikeFPTy() {
      if i < max_num_call_fregs {
        let op = self.bind_llvm_value_to_vfreg(arg)
        self.params.push(op)
      } else {
        let offset = (max_num_call_fregs - i).to_int64() * 8
        let op = self.bind_llvm_value_to_mem(arg, offset)
        self.params.push(op)
      }
    } else {
      if i < max_num_call_regs {
        let op = self.bind_llvm_value_to_vreg(arg)
        self.params.push(op)
      } else {
        let offset = (max_num_call_regs - i).to_int64() * 8
        let op = self.bind_llvm_value_to_mem(arg, offset)
        self.params.push(op)
      }
    }
  }
}

///|
fn Function::sort_llvm_basick_block(self: Self) -> Array[@IR.BasicBlock] {
  let basic_blocks : Array[@IR.BasicBlock] = Array::new()
  let entry_bb = self.llvm_func.getEntryBlock().unwrap()
  fn dfs(bb: @IR.BasicBlock, visited: Set[@IR.BasicBlock]) -> Unit {
    if visited.contains(bb) {
      return
    }
    visited.add(bb)
    for succ in bb.getSuccessors() {
      dfs(succ, visited)
    }
    basic_blocks.push(bb)
  }
  dfs(entry_bb, Set::new())
  basic_blocks.rev()
}

///|
fn Function::add_vreg(self : Self) -> Operand {
  let i = self.vreg_cnt
  let op = VReg(i)
  self.vreg_cnt += 1
  op
}

fn Function::add_vfreg(self : Self) -> Operand {
  let i = self.vfreg_cnt
  let op = VFReg(i)
  self.vfreg_cnt += 1
  op
}

///|
fn Function::bind_llvm_value_to_vreg(self : Self, val : &LLVMValue) -> Operand {
  let i = self.vreg_cnt
  let op = VReg(i)
  self.value_map[val] = op
  self.vreg_cnt += 1
  op
}

///|
fn Function::bind_llvm_value_to_vfreg(self : Self, val : &LLVMValue) -> Operand {
  let i = self.vfreg_cnt
  let op = VFReg(i)
  self.value_map[val] = op
  self.vfreg_cnt += 1
  op
}

///|
fn Function::bind_llvm_value_to_mem(
  self : Self,
  val : &LLVMValue,
  offset : Int64,
) -> Operand {
  let op = Mem(StackPtr, offset)
  self.value_map[val] = op
  op
}

///|
fn Function::get_operand_from_llvm_value(self : Self, val : &LLVMValue) -> Operand? {
  self.value_map.get(val)
}

///|
//pub fn Function::new(name : String) -> Function {
//  Function::{ name, params: [], body: [], stack_size: 0 }
//}

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

///|
fn Function::phi_elimination(self : Self) -> Unit {
  for phi in self.phi_insts {
    let dst_op = phi.defs[0]
    loop phi.uses[:] {
      [op, Label(from_label), .. rest] => {
        let from_bb_idx = self.body
          .search_by(bb => bb.label == from_label)
          .unwrap_or_else(() => {
            println("Unknown Error, phi elimination, from_bb not found.")
            panic()
          })
        let from_bb = self.body[from_bb_idx]
        let mov_inst = Instruction::{ opcode: Movq, defs: [dst_op], uses: [op] }
        from_bb.add_inst_before_terminator(mov_inst)
        continue rest
      }
      [_, _, ..] => {
        println("Unknown Error, from_bb is not a label.")
        panic()
      }
      [_] => {
        println("Unknown Error, phi elimination, uses length is not even.")
        panic()
      }
      [] => break
    }
  }
  self.delete_phi_instructions()
}

///|
fn Function::delete_phi_instructions(self : Self) -> Unit {
  for bb in self.body {
    bb.insts = bb.insts.filter(inst => !(inst.opcode is PHI))
  }
  self.phi_insts.clear()
}

fn Function::prologue_epilogue_insertion(self : Self) -> Unit {
  
}
