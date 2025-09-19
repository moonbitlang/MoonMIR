///|
/// Architecture Configuration
pub(all) struct ArchConfig {
  // Maximum Call Registers
  // If Exceeded, will spill to stack
  max_num_call_regs : Int
  max_num_call_fregs : Int
  // Whether to support select instruction
  // If false, will lower to branches
  support_select : Bool
}

///|
pub fn ArchConfig::riscv64() -> ArchConfig {
  ArchConfig::{
    max_num_call_regs: 8,
    max_num_call_fregs: 8,
    support_select: false,
  }
}

///|
pub fn ArchConfig::debug() -> ArchConfig {
  ArchConfig::{
    max_num_call_regs: 4,
    max_num_call_fregs: 4,
    support_select: false,
  }
}
