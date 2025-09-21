///|
pub(all) struct Instruction {
  opcode : OpCode
  defs : Array[Operand]
  uses : Array[Operand]
  bb : BasicBlock?
  livein : Set[Operand]
  liveout : Set[Operand]
}

///|
pub impl Show for Instruction with output(self, logger) {
  if self.defs.length() > 0 {
    let dstr = self.defs.map(op => op.to_string()).join(", ")
    logger.write_string(dstr)
    logger.write_string(" = ")
  }
  logger.write_string(self.opcode.to_string())
  logger.write_string(" ")
  if self.uses.length() > 0 {
    let ustr = self.uses.map(op => op.to_string()).join(", ")
    logger.write_string(ustr)
  }
}

///|
fn Instruction::is_terminator(self : Self) -> Bool {
  self.opcode.is_terminator()
}

///|
pub fn Instruction::new(
  opcode : OpCode,
  defs : Array[Operand],
  uses : Array[Operand],
  bb? : BasicBlock? = None,
) -> Instruction {
  // Helper function to check if operand is a register type (VReg, Reg, VFReg, FReg)
  fn is_register(op : Operand) -> Bool {
    op is VReg(_) || op is Reg(_) || op is VFReg(_) || op is FReg(_)
  }

  // Helper function to check if operand is an integer register type
  fn is_int_register(op : Operand) -> Bool {
    op is VReg(_) || op is Reg(_) || op is StackPtr || op is FramePtr
  }

  // Helper function to check if operand is a floating-point register type
  fn is_fp_register(op : Operand) -> Bool {
    op is VFReg(_) || op is FReg(_)
  }

  // Helper function to normalize binary operation uses (put immediate as second operand)
  fn normalize_binary_uses(uses : Array[Operand]) -> Array[Operand] {
    match uses {
      [Imm(_) as i, r] if is_register(r) => [r, i]
      [FImm(_) as f, r] if is_register(r) => [r, f]
      _ => uses
    }
  }

  // Validate and construct instruction based on opcode category
  match opcode {
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
    | Rem(_) =>
      // Binary operations: def = op1 op op2
      match (defs, uses) {
        ([def], [_, _]) if is_int_register(def) => {
          let normalized_uses = normalize_binary_uses(uses)
          match normalized_uses {
            [r1, r2] if is_int_register(r1) && is_int_register(r2) =>
              Instruction::{
                opcode,
                defs,
                uses: normalized_uses,
                bb,
                livein: Set::new(),
                liveout: Set::new(),
              }
            [r, Imm(_)] if is_int_register(r) =>
              Instruction::{
                opcode,
                defs,
                uses: normalized_uses,
                bb,
                livein: Set::new(),
                liveout: Set::new(),
              }
            [Imm(_), Imm(_)] =>
              // Allow two immediates (for constant folding scenarios)
              Instruction::{
                opcode,
                defs,
                uses: normalized_uses,
                bb,
                livein: Set::new(),
                liveout: Set::new(),
              }
            _ => {
              println("Invalid binary arithmetic instruction:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        }
        _ => {
          println("Binary arithmetic instruction requires 1 def and 2 uses:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Floating-point binary operations
    FAddS | FAddD | FSubS | FSubD | FMulS | FMulD | FDivS | FDivD =>
      match (defs, uses) {
        ([def], [_, _]) if is_fp_register(def) => {
          let normalized_uses = normalize_binary_uses(uses)
          match normalized_uses {
            [r1, r2] if is_fp_register(r1) && is_fp_register(r2) =>
              Instruction::{
                opcode,
                defs,
                uses: normalized_uses,
                bb,
                livein: Set::new(),
                liveout: Set::new(),
              }
            [r, FImm(_)] if is_fp_register(r) =>
              Instruction::{
                opcode,
                defs,
                uses: normalized_uses,
                bb,
                livein: Set::new(),
                liveout: Set::new(),
              }
            [FImm(_), FImm(_)] =>
              // Allow two floating-point immediates (for constant folding scenarios)
              Instruction::{
                opcode,
                defs,
                uses: normalized_uses,
                bb,
                livein: Set::new(),
                liveout: Set::new(),
              }
            _ => {
              println("Invalid floating-point binary instruction:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        }
        _ => {
          println(
            "Floating-point binary instruction requires 1 FP def and 2 FP uses:",
          )
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Bitwise and shift operations
    And | Or | Xor | Shl | LShr | AShr =>
      match (defs, uses) {
        ([def], [_, _]) if is_int_register(def) => {
          let normalized_uses = normalize_binary_uses(uses)
          match normalized_uses {
            [r1, r2] if is_int_register(r1) &&
              (is_int_register(r2) || r2 is Imm(_)) =>
              Instruction::{
                opcode,
                defs,
                uses: normalized_uses,
                bb,
                livein: Set::new(),
                liveout: Set::new(),
              }
            _ => {
              println("Invalid bitwise/shift instruction:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        }
        _ => {
          println("Bitwise/shift instruction requires 1 def and 2 uses:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Load operations
    Loadb | Loadw | Loadl | Loadq | Load(_) =>
      match (defs, uses) {
        ([def], [addr]) if is_int_register(def) =>
          match addr {
            Mem(_, _) | Imm(_) | Label(_) =>
              Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
            r if is_int_register(r) =>
              // Keep register as is - it represents a pointer
              Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
            _ => {
              println("Invalid load instruction address:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        _ => {
          println("Load instruction requires 1 def and 1 address:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Floating-point load operations
    FLoadS | FLoadD =>
      match (defs, uses) {
        ([def], [addr]) if is_fp_register(def) =>
          match addr {
            Mem(_, _) =>
              Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
            r if is_int_register(r) =>
              // Keep register as is - it represents a pointer
              Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
            _ => {
              println("Invalid floating-point load instruction:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        _ => {
          println("FP load instruction requires 1 FP def and 1 address:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Store operations
    Storeb | Storew | Storel | Storeq | Store(_) =>
      match (defs, uses) {
        ([], [addr, _]) =>
          match addr {
            Mem(_, _) =>
              Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
            Imm(_) =>
              // Treat immediate as absolute address
              Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
            r if is_int_register(r) =>
              // Keep register as is - it represents a pointer
              Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
            _ => {
              println("Invalid store instruction address:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        _ => {
          println("Store instruction requires 0 defs and 2 uses (addr, value):")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Floating-point store operations
    FStoreS | FStoreD =>
      match (defs, uses) {
        ([], [addr, value]) if is_fp_register(value) || value is FImm(_) =>
          match addr {
            Mem(_, _) =>
              Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
            r if is_int_register(r) =>
              // Keep register as is - it represents a pointer
              Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
            _ => {
              println("Invalid floating-point store instruction:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        _ => {
          println(
            "FP store instruction requires 0 defs and 2 uses (addr, FP value):",
          )
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Move operations
    Movb | Movw | Movl | Movq | Mov(_) =>
      match (defs, uses) {
        ([def], [src]) if is_int_register(def) =>
          match src {
            s if is_int_register(s) || s is Imm(_) || s is Mem(_, _) =>
              Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
            _ => {
              println("Invalid move instruction source:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        _ => {
          println("Move instruction requires 1 def and 1 use:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Floating-point move operations
    FMovS | FMovD =>
      match (defs, uses) {
        ([def], [src]) if is_fp_register(def) =>
          match src {
            s if is_fp_register(s) || s is FImm(_) || s is Mem(_, _) =>
              Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
            _ => {
              println("Invalid floating-point move instruction:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        _ => {
          println("FP move instruction requires 1 FP def and 1 use:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Comparison operations
    Eq | Ne | Gt | Ge | Lt | Le | Equ | Neu | Gtu | Geu | Ltu | Leu =>
      match (defs, uses) {
        ([def], [_, _]) if is_int_register(def) => {
          let normalized_uses = normalize_binary_uses(uses)
          match normalized_uses {
            [r1, r2] if is_int_register(r1) &&
              (is_int_register(r2) || r2 is Imm(_)) =>
              Instruction::{
                opcode,
                defs,
                uses: normalized_uses,
                bb,
                livein: Set::new(),
                liveout: Set::new(),
              }
            _ => {
              println("Invalid comparison instruction:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        }
        _ => {
          println("Comparison instruction requires 1 def and 2 uses:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
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
    | FleD =>
      match (defs, uses) {
        ([def], [_, _]) if is_int_register(def) => {
          // FP comparisons produce integer result
          let normalized_uses = normalize_binary_uses(uses)
          match normalized_uses {
            [r1, r2] if is_fp_register(r1) &&
              (is_fp_register(r2) || r2 is FImm(_)) =>
              Instruction::{
                opcode,
                defs,
                uses: normalized_uses,
                bb,
                livein: Set::new(),
                liveout: Set::new(),
              }
            _ => {
              println("Invalid floating-point comparison instruction:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        }
        _ => {
          println("FP comparison requires 1 int def and 2 FP uses:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
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
      match (defs, uses) {
        ([], [op1, op2, Label(_) as true_label, Label(_) as false_label]) => {
          let cmp_uses = [op1, op2]
          let normalized_cmp = normalize_binary_uses(cmp_uses)
          match normalized_cmp {
            [r1, r2] if is_int_register(r1) &&
              (is_int_register(r2) || r2 is Imm(_)) =>
              Instruction::{
                opcode,
                defs,
                uses: [
                  normalized_cmp[0],
                  normalized_cmp[1],
                  true_label,
                  false_label,
                ],
                bb,
                livein: Set::new(),
                liveout: Set::new(),
              }
            _ => {
              println("Invalid branch instruction operands:")
              println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
              panic()
            }
          }
        }
        _ => {
          println(
            "Branch instruction requires 0 defs and 4 uses (op1, op2, true_label, false_label):",
          )
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Jump operation
    Jmp =>
      match (defs, uses) {
        ([], [Label(_)]) =>
          Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
        _ => {
          println("Jump instruction requires 0 defs and 1 label:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Cast operations
    Trunc | ZExt | SExt | FPTrunc | FPExt | BitCast =>
      match (defs, uses) {
        ([def], [src]) if is_register(def) && is_register(src) =>
          Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
        _ => {
          println("Cast instruction requires 1 def and 1 use:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Type conversion operations
    FPToSI(_, _) | FPToUI(_, _) =>
      match (defs, uses) {
        ([def], [src]) if is_int_register(def) && is_fp_register(src) =>
          Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
        _ => {
          println("FP-to-int conversion requires 1 int def and 1 FP use:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }
    SIToFP(_, _) | UIToFP(_, _) =>
      match (defs, uses) {
        ([def], [src]) if is_fp_register(def) && is_int_register(src) =>
          Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
        _ => {
          println("Int-to-FP conversion requires 1 FP def and 1 int use:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // PHI node
    PHI =>
      match defs {
        [def] if is_register(def) => {
          // PHI uses should be alternating values and labels
          if uses.length() % 2 != 0 {
            println(
              "PHI instruction requires even number of uses (value, label pairs):",
            )
            println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
            panic()
          }
          for i = 0; i < uses.length(); i = i + 2 {
            let value = uses[i]
            let label = uses[i + 1]
            if !(is_register(value) || value is Imm(_) || value is FImm(_)) {
              println("PHI value at index \{i} must be register or immediate:")
              println("  value: \{value}")
              panic()
            }
            if !(label is Label(_)) {
              println("PHI label at index \{i + 1} must be a Label:")
              println("  label: \{label}")
              panic()
            }
          }
          Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
        }
        _ => {
          println("PHI instruction requires exactly 1 def:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Select operation
    Select =>
      match (defs, uses) {
        ([def], [cond, _, _]) if is_register(def) => {
          if !(is_int_register(cond) || cond is Imm(_)) {
            println("Select condition must be integer register or immediate:")
            println("  cond: \{cond}")
            panic()
          }
          Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
        }
        _ => {
          println(
            "Select instruction requires 1 def and 3 uses (cond, true_val, false_val):",
          )
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Call operation
    Call =>
      match uses {
        [Label(_), ..] =>
          // First use must be function label, rest are arguments
          Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
        _ => {
          println("Call instruction requires label as first use:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Return operation
    Ret =>
      match (defs, uses) {
        ([], [_] | []) =>
          Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
        _ => {
          println("Return instruction requires 0 defs and 0 or 1 use:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Nop operation
    Nop =>
      match (defs, uses) {
        ([], []) =>
          Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
        _ => {
          println("Nop instruction requires 0 defs and 0 uses:")
          println("  opcode: \{opcode}, defs: \{defs}, uses: \{uses}")
          panic()
        }
      }

    // Intrinsic operations
    Intrinsic(_) =>
      // Intrinsics can have arbitrary operands, so we allow them
      Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }

    // Unhandled floating-point remainder operations
    FRemS | FRemD | FNegS | FNegD =>
      // These need specific validation based on their semantics
      Instruction::{ opcode, defs, uses, bb, livein: Set::new(), liveout: Set::new() }
  }
}
