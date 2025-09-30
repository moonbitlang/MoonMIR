///|
///
/// in riscv64, we only have 8 integer argument registers (a0-a7)
/// other arguments are passed on the stack
test "twelve args" {
  let mod = Module::new(ArchConfig::riscv64())
  let arg_pats : Array[ArgPattern] = [I, I, I, I, I, I, I, I, I, I, I, I]
  let func = mod.add_function("foo", arg_pats)
  let expected =
    #|func foo(a0, a1, a2, a3, a4, a5, a6, a7, (fp), (fp + 8), (fp + 16), (fp + 24)) {
    #|}
    #|
  inspect(func, content=expected)
}

///|
test "alternate arg and farg without spilling" {
  let mod = Module::new(ArchConfig::riscv64())
  let arg_pats : Array[ArgPattern] = [I, F, I, F, I, F, I, F]
  let func = mod.add_function("foo", arg_pats)
  let expected =
    #|func foo(a0, fa0, a1, fa1, a2, fa2, a3, fa3) {
    #|}
    #|
  inspect(func, content=expected)
}

///|
test "alternate arg and farg spill arg" {
  let mod = Module::new(ArchConfig::riscv64())
  let arg_pats : Array[ArgPattern] = [I, I, I, I, I, I, I, I, I, I, F, F]
  let func = mod.add_function("foo", arg_pats)
  let expected =
    #|func foo(a0, a1, a2, a3, a4, a5, a6, a7, (fp), (fp + 8), fa0, fa1) {
    #|}
    #|
  inspect(func, content=expected)
}

///|
test "alternate arg and farg spill farg" {
  let mod = Module::new(ArchConfig::riscv64())
  let arg_pats : Array[ArgPattern] = [F, F, F, F, F, F, F, F, F, F, I, I]
  let func = mod.add_function("foo", arg_pats)
  let expected =
    #|func foo(fa0, fa1, fa2, fa3, fa4, fa5, fa6, fa7, (fp), (fp + 8), a0, a1) {
    #|}
    #|
  inspect(func, content=expected)
}
