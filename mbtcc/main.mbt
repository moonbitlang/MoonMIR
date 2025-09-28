///|
fn main {
  let rv64_config = @GMIR.ArchConfig::riscv64()
  let help_info =
    #|Usage: mbtcc [options] <input_file>
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
  let parser_ctx = @parser.ParserContext::create_by_file(input_file)
  parser_ctx.tokenize() catch {
    err => {
      println("Tokenization error: \{err}")
      return
    }
  }
  parser_ctx.preprocess() catch {
    err => {
      println("Preprocessing error: \{err}")
      return
    }
  }
  parser_ctx.parse() catch {
    @parser.ParseError((idx, msg)) => {
      let msg = parser_ctx.get_error_msg(idx, msg)
      println("Parse error: " + msg)
      return
    }
    _ => ()
  }
  let codegen = @codegen.CodeGenContext::from_parser(parser_ctx)
  codegen.run() catch {
    err => {
      println("Code generation error: \{err}")
      return
    }
  }
  let mod = codegen.llvm_mod
  if args.contains("-emit-llvm") {
    if args.search("-o") is Some(idx) && idx + 1 < args.length() {
      let output_file = args[idx + 1]
      let s = mod.to_string()
      @fs.write_string_to_file(output_file, s) catch {
        err => {
          println("Error writing LLVM IR to file: \{err}")
          return
        }
      }
    } else {
      println(mod)
    }
    return
  }
  if args.contains("--print-all") {
    println("==================== LLVM IR ================")
    println(mod)
  }
  let gmir = @GMIR.Module::new(mod, rv64_config)
  gmir.run_ir_translation() catch {
    e => {
      println("Error during GMIR translation: \{e}")
      return
    }
  }
  if args.contains("--stop-after=IRTranslate") {
    println(gmir)
  }
  if args.contains("--print-all") {
    println("==================== GMIR ================")
    println(gmir)
  }
  gmir.legalize()
  if args.contains("--stop-after=Legalize") {
    println(gmir)
    return
  }
  if args.contains("--print-all") {
    println("==================== GMIR Legalized ================")
    println(gmir)
  }
  let gmir = gmir.alloc_register() catch {
    e => {
      println("Error during GMIR register allocation: \{e}")
      return
    }
  }
  if args.contains("--stop-after=RegAlloc") {
    println(gmir)
    return
  }
  if args.contains("--print-all") {
    println("==================== GMIR RegAlloc ================")
    println(gmir)
  }
  let gmir = gmir.post_ra() catch {
    e => {
      println("Error during GMIR post-RA adjustments: \{e}")
      return
    }
  }
  if args.contains("--stop-after=PostRA") {
    println(gmir)
    return
  }
  if args.contains("--print-all") {
    println("==================== GMIR PostRA ================")
    println(gmir)
  }
  let gmir = gmir.peephole_optimizations()
  if args.contains("--stop-after=PeepholeOpt") {
    println(gmir)
    return
  }
  if args.contains("--print-all") {
    println(
      "==================== GMIR PostRA Peephole Optimazation ================",
    )
    println(gmir)
  }
  let riscv_asm = @riscv.from_gmir_module(gmir) catch {
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
