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

fn Function::phi_elimination(self: Self) -> Unit {
  let phis: Array[Instruction] = []
  for bb in self.body {
    for inst in bb.insts {
      if inst is { opcode: PHI, .. } {
        phis.push(inst)
      }
    }
  }
  for phi in phis {
    let dst_op = phi.defs[0]
    loop phi.uses[:] {
      [op, Label(from_label), ..rest] => {
        let from_bb_idx = self.body.search_by(bb => bb.label == from_label).unwrap_or_else(() => {
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

fn Function::delete_phi_instructions(self: Self) -> Unit {
  for bb in self.body {
    bb.insts = bb.insts.filter(inst => !(inst.opcode is PHI))
  }
}
