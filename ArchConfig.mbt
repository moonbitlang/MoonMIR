///|
/// Architecture Configuration
pub(all) struct ArchConfig {
  // The Number of Total Physical Registers
  // max_num_reg should be = num_arg_regs + num_temp_regs + num_saved_regs
  // not include special registers like zero, ra, sp
  max_num_reg : Int
  // The Number of Total Physical Floating Point Registers
  // max_num_freg should be = num_arg_fregs + num_temp_fregs + num_saved_fregs
  max_num_freg : Int
  // The Number of Physicial Argument Registers
  num_arg_regs : Int
  // The Number of Physical Argument Floating Point Registers
  num_arg_fregs : Int
  // The Number of Physical Temporary Registers
  num_temp_regs : Int
  // The Number of Physical Temporary Floating Point Registers
  num_temp_fregs : Int
  // The Number of Physical Saved Registers
  num_saved_regs : Int
  // The Number of Physical Saved Floating Point Registers
  num_saved_fregs : Int
  // Whether to support select instruction
  // If false, will lower to branches
  support_select : Bool
}

///|
pub fn ArchConfig::riscv64() -> ArchConfig {
  ArchConfig::{
    max_num_reg: 17,
    max_num_freg: 17,
    num_arg_regs: 8,
    num_arg_fregs: 8,
    num_temp_regs: 6,
    num_temp_fregs: 6,
    num_saved_regs: 11,
    num_saved_fregs: 11,
    support_select: false,
  }
}

///|
pub fn ArchConfig::debug() -> ArchConfig {
  ArchConfig::{
    max_num_reg: 8,
    max_num_freg: 8,
    num_arg_regs: 4,
    num_arg_fregs: 4,
    num_temp_regs: 2,
    num_temp_fregs: 2,
    num_saved_regs: 2,
    num_saved_fregs: 2,
    support_select: false,
  }
}
