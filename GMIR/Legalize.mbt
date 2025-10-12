//|

///|
pub fn Module::legalize(self : Self) -> Unit {
  if self.legalized {
    return
  }
  self.functions.each(f => f.legalize())
  self.legalized = true
}

///|
pub fn Function::legalize(func : Function) -> Unit {
  if func.legalized {
    return
  }
  for bb in func.body {
    bb.legalize()
  }
  func.legalized = true
}

///|
pub fn BasicBlock::legalize(self : BasicBlock) -> Unit {
  let new_insts : Array[Instruction] = Array::new()
  for inst in self.insts {
    inst.legalize().each(new_inst => new_insts.push(new_inst))
  }
  self.insts = new_insts
}

///|
pub fn Instruction::legalize(self : Instruction) -> Array[Instruction] {
  // Helper function to check if operand is a register type (VReg, Reg, VFReg, FReg)
  fn is_register(op : Operand) -> Bool {
    op
    is (VReg(_)
    | Reg(_)
    | VFReg(_)
    | FReg(_)
    | StackPtr
    | FramePtr
    | AReg(_)
    | FAReg(_)
    | TReg(_)
    | FTReg(_)
    | SReg(_)
    | FSReg(_))
  }

  // Helper function to normalize binary operation uses (put immediate as second operand)
  fn normalize_binary_uses(uses : Array[Operand]) -> Array[Operand] {
    match uses {
      [Imm(_) as i, r] if is_register(r) => [r, i]
      [FImm(_) as f, r] if is_register(r) => [r, f]
      _ => uses
    }
  }

  // Now perform validation and normalization based on the opcode
  match self.opcode {
    // Binary arithmetic operations (integer)
    Addb
    | Addw
    | Addl
    | Addq
    | Add(_)
    | Subb
    | Subw
    | Subl
    | Subq
    | Sub(_)
    | Mulb
    | Mulw
    | Mull
    | Mulq
    | Mul(_)
    | Divb
    | Divw
    | Divl
    | Divq
    | Div(_)
    | Remb
    | Remw
    | Reml
    | Remq
    | Rem(_) => {
      // Normalize operand order for binary operations
      let normalized_uses = normalize_binary_uses(self.uses)
      // Create new instruction with normalized uses
      [Instruction::{ ..self, uses: normalized_uses }]
    }

    // Floating-point binary operations
    FAddS | FAddD | FSubS | FSubD | FMulS | FMulD | FDivS | FDivD => {
      let normalized_uses = normalize_binary_uses(self.uses)
      [Instruction::{ ..self, uses: normalized_uses }]
    }

    // Bitwise and shift operations
    And | Or | Xor | Shl | LShr | AShr => {
      let normalized_uses = normalize_binary_uses(self.uses)
      [Instruction::{ ..self, uses: normalized_uses }]
    }

    // Comparison operations
    Eq | Ne | Gt | Ge | Lt | Le | Equ | Neu | Gtu | Geu | Ltu | Leu => {
      let normalized_uses = normalize_binary_uses(self.uses)
      [Instruction::{ ..self, uses: normalized_uses }]
    }

    // Floating-point comparison operations
    FeqS
    | FneS
    | FgtS
    | FgeS
    | FltS
    | FleS
    | FeqD
    | FneD
    | FgtD
    | FgeD
    | FltD
    | FleD => {
      let normalized_uses = normalize_binary_uses(self.uses)
      [Instruction::{ ..self, uses: normalized_uses }]
    }

    // Branch operations
    Beq
    | Bne
    | Bgt
    | Bge
    | Blt
    | Ble
    | Bequ
    | Bneu
    | Bgtu
    | Bgeu
    | Bltu
    | Bleu =>
      // Normalize comparison operands for branch instructions
      match self.uses {
        [op1, op2, true_label, false_label] => {
          let cmp_uses = [op1, op2]
          let normalized_cmp = normalize_binary_uses(cmp_uses)
          [
            Instruction::{
              ..self,
              uses: [
                normalized_cmp[0],
                normalized_cmp[1],
                true_label,
                false_label,
              ],
            },
          ]
        }
        _ => [self] // If it doesn't match expected pattern, keep as is
      }

    // All other operations - return as is
    _ => [self]
  }
}
