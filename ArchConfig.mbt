///|
/// Architecture Configuration
pub(all) struct ArchConfig {
  arch_name : String
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
    arch_name: "riscv64",
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
pub fn ArchConfig::aarch64() -> ArchConfig {
  ArchConfig::{
    arch_name: "aarch64",
    max_num_reg: 19,        // X0-X30 minus reserved (SP, X18)
    max_num_freg: 32,       // D0-D31
    num_arg_regs: 8,        // X0-X7
    num_arg_fregs: 8,       // D0-D7
    num_temp_regs: 7,       // X9-X15
    num_temp_fregs: 6,      // D16-D21
    num_saved_regs: 11,     // X19-X28, X8 (can be saved), X29
    num_saved_fregs: 8,     // D8-D15
    support_select: false,
  }
}

///|
pub fn ArchConfig::debug() -> ArchConfig {
  ArchConfig::{
    arch_name: "demo",
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
