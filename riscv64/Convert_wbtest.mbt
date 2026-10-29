///|
test "conversion errors retain diagnostic messages" {
  let message = try {
    raise MIRToRiscvError("unsupported operand")
  } catch {
    MIRToRiscvError(message) => message
  }
  assert_eq(message, "unsupported operand")
}
