///|
test "conversion errors retain diagnostic messages" {
  let message = try {
    raise MIRToAArch64Error("unsupported operand")
  } catch {
    MIRToAArch64Error(message) => message
  }
  assert_eq(message, "unsupported operand")
}
