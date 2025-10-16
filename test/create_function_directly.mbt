///|
typealias @MoonMIR.(
  Module,
  //Function,
  BasicBlock,
  ArgPattern,
  IRBuilder,
  ArchConfig
)

///|
test "simple two int arg adding" {
  let mod = Module::new(ArchConfig::riscv64())
  let func = mod.add_function("add", [I, I], false)
  let entry_bb = func.append_basic_block("entry")
  let builder = IRBuilder::new(func, entry_bb)
  let a0 = func.get_param(0).unwrap()
  let a1 = func.get_param(1).unwrap()
  guard a0 is IRegister(a0)
  guard a1 is IRegister(a1)
  builder.build_ibinary(Add, 32, dst=AReg(0), src1=a0, src2=a1)
  |> BasicBlock::push(entry_bb, _)
  builder.build_ret() |> BasicBlock::push(entry_bb, _)
  let expected =
    #|func add(a0, a1) {
    #|entry:
    #|  a0 = add.i32 a0, a1
    #|  ret
    #|}
    #|
  inspect(func, content=expected)
}
