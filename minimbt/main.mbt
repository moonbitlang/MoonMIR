///|
fn main {
  // Determine target architecture
  let args = @env.args()
  let target_arch = if args.contains("--target=aarch64") ||
    args.contains("--target=arm64") {
    "aarch64"
  } else {
    "riscv64" // Default to RISC-V
  }
  let arch_config = match target_arch {
    "aarch64" => @MoonMIR.ArchConfig::aarch64()
    "riscv64" => @MoonMIR.ArchConfig::riscv64()
    _ => @MoonMIR.ArchConfig::riscv64() // fallback
  }
  let help_info =
    #|Usage: mbtcc [options] <input_file>
    #|
    #|Options:
    #|  -h, --help                 Show this help message
    #|  -f, --file <input_file>    Specify the input file
    #|  -o <output_file>           Specify the output file name
    #|  --target=<arch>            Target architecture (riscv64, aarch64/arm64)
    #|  -emit-llvm                 Output LLVM IR
    #|  --stop-after=IRTranslate   Stop after IR translation
    #|  --stop-after=Legalize      Stop after legalization
    #|  --stop-after=RegAlloc      Stop after register allocation
    #|  --stop-after=PostRA        Stop after post register allocation
    #|  --print-all               Print intermediate representations at all stages
  if args.length() == 1 || args.contains("-h") || args.contains("--help") {
    println(help_info)
    return
  }
  let input_file = if args.search("-f") is Some(idx) && idx + 1 < args.length() {
    args[idx + 1]
  } else if args.search("--file") is Some(idx) && idx + 1 < args.length() {
    args[idx + 1]
  } else {
    println("Error: No input file specified.")
    println(help_info)
    return
  }
  let code = @fs.read_file_to_string(input_file) catch {
    err => {
      println("Error reading input file: \{err}")
      return
    }
  }
  let llvm_mod = @codegen.codegen_all(code) catch {
    e => {
      println("Error during code generation: \{e}")
      return
    }
  }
  if args.contains("-emit-llvm") {
    if args.search("-o") is Some(idx) && idx + 1 < args.length() {
      let output_file = args[idx + 1]
      let s = llvm_mod.to_string()
      @fs.write_string_to_file(output_file, s) catch {
        err => {
          println("Error writing LLVM IR to file: \{err}")
          return
        }
      }
    } else {
      println(llvm_mod)
    }
    return
  }
  if args.contains("--print-all") {
    println("==================== LLVM IR ================")
    println(llvm_mod)
  }
  let mir_mod = @MoonMIR.Module::new(arch_config)
  mir_mod.translate_llvm_module(llvm_mod) catch {
    e => {
      println("Error during MoonMIR translation: \{e}")
      return
    }
  }
  if args.contains("--stop-after=IRTranslate") {
    println(mir_mod)
  }
  if args.contains("--print-all") {
    println("==================== MoonMIR ================")
    println(mir_mod)
  }
  mir_mod.legalize() catch {
    e => {
      println("Error during MoonMIR legalization: \{e}")
      return
    }
  }
  if args.contains("--stop-after=Legalize") {
    println(mir_mod)
    return
  }
  if args.contains("--print-all") {
    println("==================== MoonMIR Legalized ================")
    println(mir_mod)
  }
  mir_mod.alloc_register() catch {
    e => {
      println("Error during MoonMIR register allocation: \{e}")
      return
    }
  }
  if args.contains("--stop-after=RegAlloc") {
    println(mir_mod)
    return
  }
  if args.contains("--print-all") {
    println("==================== MoonMIR RegAlloc ================")
    println(mir_mod)
  }
  mir_mod.post_ra()
  if args.contains("--stop-after=PostRA") {
    println(mir_mod)
    return
  }
  if args.contains("--print-all") {
    println("==================== MoonMIR PostRA ================")
    println(mir_mod)
  }
  // Generate assembly string based on target architecture
  let asm_string = match target_arch {
    "aarch64" => {
      let aarch64_asm = @aarch64.mir_module_to_aarch64(mir_mod) catch {
        e => {
          println("Error during AArch64 assembly generation: \{e}")
          return
        }
      }
      let mut s = ""
      aarch64_asm.each(line => s += if line is Label(_) {
        line.to_string() + "\n"
      } else {
        "    " + line.to_string() + "\n"
      })
      s
    }
    "riscv64" => {
      let riscv_asm = @riscv.mir_module_to_riscv(mir_mod) catch {
        e => {
          println("Error during RISCV assembly generation: \{e}")
          return
        }
      }
      let mut s = ""
      riscv_asm.each(line => s += if line is Label(_) {
        line.to_string() + "\n"
      } else {
        "    " + line.to_string() + "\n"
      })
      s
    }
    _ => {
      println("Unsupported target architecture: \{target_arch}")
      return
    }
  }
  if args.contains("-o") &&
    args.search("-o") is Some(idx) &&
    idx + 1 < args.length() {
    let output_file = args[idx + 1]
    @fs.write_string_to_file(output_file, asm_string) catch {
      err => {
        println("Error writing assembly to file: \{err}")
        return
      }
    }
    return
  }
  println(asm_string)
}
