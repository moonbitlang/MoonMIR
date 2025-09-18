# Calling Convention Implementation Notes

## Current Implementation Status

The Legalize pass handles function parameter and call argument spilling according to the specified register limits (`max_num_call_regs` and `max_num_call_fregs`).

## The Stack Frame Issue

### Correct Calling Convention

In standard calling conventions (RISC-V, x86-64, ARM):

1. **Caller** pushes excess arguments onto **its own stack**
2. **Callee** accesses these arguments from the **caller's stack frame**

```
Higher addresses
┌─────────────────┐
│  Caller's Frame │
│  ...            │
│  arg8           │ <- sp_caller - 32
│  arg7           │ <- sp_caller - 24  
│  arg6           │ <- sp_caller - 16
│  arg5           │ <- sp_caller - 8
│  return addr    │ <- sp_caller
├─────────────────┤
│  Callee's Frame │ <- sp_callee (current SP)
│  ...            │
└─────────────────┘
Lower addresses
```

### How Parameters Should Be Accessed

For a function with 8 parameters (with max 4 registers):
- Parameters 1-4: In registers `%v0, %v1, %v2, %v3`
- Parameters 5-8: On stack at `(sp - 8), (sp - 16), (sp - 24), (sp - 32)`

The negative offsets indicate accessing memory "above" the current stack pointer.

### Current Implementation Limitation

Due to VM limitations, we currently use **positive offsets**:
```moonbit
func eight_params(%v0, %v1, %v2, %v3, (sp + 0), (sp + 8), (sp + 16), (sp + 24))
```

This is **incorrect** but allows the VM to work. The correct form should be:
```moonbit
func eight_params(%v0, %v1, %v2, %v3, (sp - 8), (sp - 16), (sp - 24), (sp - 32))
```

## TODO for Full Correctness

1. **Fix VM**: Modify `VirtualMachine.mbt` to support negative stack offsets
2. **Add Frame Pointer**: Implement frame pointer (FP) support for more robust stack frame management
3. **Update Legalize**: Change `make_caller_stack_param` to use correct negative offsets

## Impact on Code Generation

When this is fixed, the RISC-V backend will need to:
1. Generate proper stack frame setup/teardown
2. Use correct offsets for accessing caller's parameters
3. Handle stack pointer adjustments correctly

## Testing Note

Current tests pass because:
- The VM treats all memory as a flat array
- Both caller and callee use the same (incorrect) positive offsets
- The values end up in the right relative positions

However, this won't work with real assembly generation where the stack grows downward.