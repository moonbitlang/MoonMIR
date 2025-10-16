///|
fn main {
  let rv64_config = @MoonMIR.ArchConfig::riscv64()
  let help_info =
    #|Usage: tmbt [options] <input_file>
    #|
    #|Options:
    #|  -h, --help                Show this help message
    #|  -f, --file <input_file>   Specify the input file
    #|  -o <output_file>          Specify the output file name
    #|  -emit-llvm                Output LLVM IR
    #|  --stop-after=IRTranslate   Stop after IR translation
    #|  --stop-after=Legalize      Stop after legalization
    #|  --stop-after=RegAlloc      Stop after register allocation
    #|  --stop-after=PostRA        Stop after post register allocation
    #|  --print-all               Print intermediate representations at all stages
  let args = @env.args()
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
      println("Error reading file '\{input_file}': \{err}")
      return
    }
  }
  let llvm_mod = @TinyMoonBit.compile(code) catch {
    e => {
      println("Error during TinyMoonBit compilation: \{e}")
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
  let mir_mod = @MoonMIR.Module::new(rv64_config)
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
  let riscv_asm = @riscv.mir_module_to_riscv(mir_mod) catch {
    e => {
      println("Error during RISCV assembly generation: \{e}")
      return
    }
  }
  if args.contains("-o") &&
    args.search("-o") is Some(idx) &&
    idx + 1 < args.length() {
    let output_file = args[idx + 1]
    let mut s = ""
    riscv_asm.each(line => s += if line is Label(_) {
      line.to_string() + "\n"
    } else {
      "  " + line.to_string() + "\n"
    })
    @fs.write_string_to_file(output_file, s) catch {
      err => {
        println("Error writing assembly to file: \{err}")
        return
      }
    }
    return
  }
  riscv_asm.each(line => println(line))
}
