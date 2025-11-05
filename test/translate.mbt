///|
let rv64 : ArchConfig = ArchConfig::riscv64()

///|
test "Simple Int32 Binary IRTranslate Test" {
  let code =
    #|fn add(x: Int, y: Int) -> Int {
    #|  let a = x + y
    #|  let b = x - y
    #|  let c = x * y
    #|  let d = x / y
    #|  let e = x % y
    #|  let f = x & y
    #|  let g = x | y
    #|  g
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)

  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("add").unwrap()
  inspect(
    mir_func,
    content=(
      #|func add(a0, a1) {
      #|entry:
      #|  v0 = move.i32 a0
      #|  v1 = move.i32 a1
      #|  v2 = or.i32 v0, v1
      #|  a0 = move.i64 v2
      #|  ret
      #|}
      #|
    ),
  )
}

///|
test "Simple Int64 Binary IRTranslate Test" {
  let code =
    #|fn add(x: Int64, y: Int64) -> Int64 {
    #|  let a = x + y
    #|  let b = x - y
    #|  let c = x * y
    #|  let d = x / y
    #|  let e = x % y
    #|  let f = x & y
    #|  let g = x | y
    #|  g
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)

  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("add").unwrap()
  inspect(mir_func, content=(
    #|func add(a0, a1) {
    #|entry:
    #|  v0 = move.i64 a0
    #|  v1 = move.i64 a1
    #|  v2 = or.i64 v0, v1
    #|  a0 = move.i64 v2
    #|  ret
    #|}
    #|
  ))
}

///|
test "Simple Float Binary IRTranslate Test" {
  let code =
    #|fn add(x: Float, y: Float) -> Float {
    #|  let a = x + y
    #|  let b = x - y
    #|  let c = x * y
    #|  let d = x / y
    #|  d
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)

  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("add").unwrap()
  inspect(
    mir_func,
    content=(
      #|func add(fa0, fa1) {
      #|entry:
      #|  vf0 = move.f32 fa0
      #|  vf1 = move.f32 fa1
      #|  vf2 = fdiv.f32 vf0, vf1
      #|  fa0 = move.f64 vf2
      #|  ret
      #|}
      #|

    ),
  )
}

///|
test "Simple Double Binary IRTranslate Test" {
  let code =
    #|fn add(x: Double, y: Double) -> Double {
    #|  let d = x / y
    #|  d
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)

  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("add").unwrap()
  inspect(mir_func, content=(
    #|func add(fa0, fa1) {
    #|entry:
    #|  vf0 = move.f64 fa0
    #|  vf1 = move.f64 fa1
    #|  vf2 = fdiv.f64 vf0, vf1
    #|  fa0 = move.f64 vf2
    #|  ret
    #|}
    #|
  ))
}

///|
test "Simple Alloca, Store and Load IRTranslate Test" {
  let code =
    #|fn demo() -> Int {
    #|  let mut a = 10  // a is in memory
    #|  return a
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)
  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("demo").unwrap()
  let expected =
    #|func demo() {
    #|entry:
    #|  v1 = move.i32 10
    #|  store.i32 (fp' - 4), v1
    #|  v0 = load.i32 (fp' - 4)
    #|  a0 = move.i64 v0
    #|  ret
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
test "Complex Int Binary IRTranslate Test" {
  let code =
    #|fn demo() -> Int {
    #|  let mut a = 10  // a is in memory
    #|  let b = a + 20
    #|  let c = 50 - a
    #|  return 0
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)
  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("demo").unwrap()
  inspect(mir_func, content=(
    #|func demo() {
    #|entry:
    #|  v2 = move.i32 10
    #|  store.i32 (fp' - 4), v2
    #|  v0 = load.i32 (fp' - 4)
    #|  v1 = load.i32 (fp' - 4)
    #|  a0 = move.i64 0
    #|  ret
    #|}
    #|
  ))
}

///|
test "Complex Float Binary IRTranslate Test" {
  let code =
    #|fn demo() -> Float {
    #|  let mut a = 1.0F  // a is in memory
    #|  let b = a + 2.0F
    #|  let c = 5.0F - a
    #|  return 0.0F
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)
  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("demo").unwrap()
  inspect(mir_func, content=(
    #|func demo() {
    #|entry:
    #|  vf2 = move.f32 1
    #|  store.f32 (fp' - 4), vf2
    #|  vf0 = load.f32 (fp' - 4)
    #|  vf1 = load.f32 (fp' - 4)
    #|  v0 = move.i64 0
    #|  vf3 = fmovei.f64 v0
    #|  fa0 = move.f64 vf3
    #|  ret
    #|}
    #|
  ))
}

///|
test "ICmp IRTranslate Test" {
  let code =
    #|fn demo(a: Int, b: Int) -> Unit {
    #|  let c = a < b
    #|  let d = a <= b
    #|  let e = a > b
    #|  let f = a >= b
    #|  let g = a == b
    #|  let h = a != b
    #|  return
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)
  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("demo").unwrap()
  inspect(
    mir_func,
    content=(
      #|func demo(a0, a1) {
      #|entry:
      #|  v0 = move.i32 a0
      #|  v1 = move.i32 a1
      #|  ret
      #|}
      #|

    ),
  )
}

///|
test "FCmp IRTranslate Test" {
  let code =
    #|fn demo(a: Float, b: Float) -> Unit {
    #|  let c = a < b
    #|  let d = a <= b
    #|  let e = a > b
    #|  let f = a >= b
    #|  let g = a == b
    #|  let h = a != b
    #|  return
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)
  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("demo").unwrap()
  inspect(
    mir_func,
    content=(
      #|func demo(fa0, fa1) {
      #|entry:
      #|  vf0 = move.f32 fa0
      #|  vf1 = move.f32 fa1
      #|  ret
      #|}
      #|

    ),
  )
}

///|
test "Branch IRTranslate Test" {
  let code =
    #|fn demo(a: Int, b: Int) -> Int {
    #|  if a < b {
    #|    return a
    #|  }
    #|  return b
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)
  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("demo").unwrap()
  inspect(
    mir_func,
    content=(
      #|func demo(a0, a1) {
      #|entry:
      #|  v0 = move.i32 a0
      #|  v1 = move.i32 a1
      #|  blt v0, v1, demo_L1, demo_L2
      #|
      #|; preds: entry
      #|demo_L1:
      #|  a0 = move.i64 v0
      #|  ret
      #|
      #|; preds: entry
      #|demo_L2:
      #|  jmp demo_L3
      #|
      #|; preds: demo_L2
      #|demo_L3:
      #|  a0 = move.i64 v1
      #|  ret
      #|}
      #|
    ),
  )
}

///|
test "While IRTranslate Test" {
  let code =
    #|fn demo() -> Int {
    #|  let mut a = 0
    #|  while a < 10 {
    #|    a = a + 1
    #|  }
    #|  return a
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)
  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("demo").unwrap()
  let expected =
    #|func demo() {
    #|entry:
    #|  v5 = move.i32 0
    #|  store.i32 (fp' - 4), v5
    #|  jmp demo_L1
    #|
    #|; preds: entry, demo_L2
    #|demo_L1:
    #|  v0 = load.i32 (fp' - 4)
    #|  blt v0, 10, demo_L2, demo_L3
    #|
    #|; preds: demo_L1
    #|demo_L2:
    #|  v2 = load.i32 (fp' - 4)
    #|  v3 = add.i32 v2, 1
    #|  store.i32 (fp' - 4), v3
    #|  jmp demo_L1
    #|
    #|; preds: demo_L1
    #|demo_L3:
    #|  v4 = load.i32 (fp' - 4)
    #|  a0 = move.i64 v4
    #|  ret
    #|}
    #|
  inspect(mir_func, content=expected)
}

///|
test "Call IRTranslate Test" {
  let code =
    #|fn add(x: Int, y: Int) -> Int {
    #|  x + y
    #|}
    #|
    #|fn demo() -> Int {
    #|  let a = add(10, 20)
    #|  return a
    #|}
  let llvm_mod = @MiniMoonBit.compile(code)
  // IRTranslate
  let mir_mod = Module::new(rv64)
  mir_mod.translate_llvm_module(llvm_mod)
  let mir_func = mir_mod.get_function("demo").unwrap()
  inspect(mir_func, content=(
    #|func demo() {
    #|entry:
    #|  a0 = move.i64 10
    #|  a1 = move.i64 20
    #|  call add, a0, a1
    #|  v0 = move.i32 a0
    #|  vf0 = move.f64 fa0
    #|  a0 = move.i64 v0
    #|  ret
    #|}
    #|
  ))
}
