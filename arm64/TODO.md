# ARM64 Backend TODO List

这份文档详细列出了ARM64后端剩余的开发任务，为下一个开发者提供完整的指导。

## 📋 当前状态概览

### ✅ 已完成的功能
- [x] 基础架构设置（ArchConfig、包配置）
- [x] 完整的ARM64指令集定义（AArch64Asm.mbt）
- [x] 基础整数算术运算（add, sub, mul, div, rem）
- [x] 内存操作（基础load/store 32位和64位）
- [x] 数据移动操作（mov, 立即数加载）
- [x] 函数调用和返回
- [x] 基础分支操作（跳转、条件分支）
- [x] 编译器集成（--target=aarch64支持）

### 🚧 部分完成的功能
- [x] 逻辑运算（仅and部分完成）
- [x] 比较操作（仅le部分完成）
- [x] 位移操作（指令定义完成，转换逻辑待实现）

### ❌ 待完成的功能
- [ ] 完整的逻辑运算支持
- [ ] 完整的比较操作支持
- [ ] 完整的位移操作支持
- [ ] 位操作（not等）
- [ ] 更多内存操作（8位、16位load/store）
- [ ] 完整的分支操作
- [ ] 浮点运算
- [ ] 类型转换操作
- [ ] 地址加载操作

## 🛠️ 详细任务清单

### 1. 逻辑运算完成 (优先级：高)

**文件**: `arm64/Convert.mbt`

**任务**: 完成所有逻辑运算的转换函数

```moonbit
// 需要实现的函数：
fn i32_or_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i64_or_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i32_xor_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i64_xor_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
```

**实现模板**（参考已完成的`i32_and_mir_to_aarch64`）:
```moonbit
fn i32_or_mir_to_aarch64(
  inst : @MoonMIR.Instruction,
) -> Array[AArch64Asm] raise MIRToAArch64Error {
  guard inst is { opcode: IBinary(Or, 32), .. } else {
    println("Compiler ICE: i32_or_mir_to_aarch64 called with non-i32 or instruction: \{inst}")
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Orr32(dst, src1, src2)]  // 使用Orr32指令
    }
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Orr32Imm(dst, src1, i2.to_int())]  // 使用Orr32Imm指令
    }
    _ => raise MIRToAArch64Error("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}
```

**类似地实现**:
- `i64_or_mir_to_aarch64` (使用`Orr64`, `Orr64Imm`)
- `i32_xor_mir_to_aarch64` (使用`Eor32`, `Eor32Imm`)
- `i64_xor_mir_to_aarch64` (使用`Eor64`, `Eor64Imm`)

### 2. 位移操作完成 (优先级：高)

**文件**: `arm64/Convert.mbt`

**需要实现的函数**:
```moonbit
fn i32_shl_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i64_shl_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i32_lshr_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i64_lshr_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i32_ashr_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i64_ashr_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
```

**实现模板**:
```moonbit
fn i32_shl_mir_to_aarch64(
  inst : @MoonMIR.Instruction,
) -> Array[AArch64Asm] raise MIRToAArch64Error {
  guard inst is { opcode: IBinary(Shl, 32), .. } else {
    println("Compiler ICE: i32_shl_mir_to_aarch64 called with non-i32 shl instruction: \{inst}")
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Lsl32(dst, src1, src2)]  // 左逻辑位移
    }
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Lsl32Imm(dst, src1, i2.to_int())]  // 立即数左逻辑位移
    }
    _ => raise MIRToAArch64Error("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}
```

**位移指令映射**:
- `Shl` → `Lsl` (左逻辑位移)
- `LShr` → `Lsr` (右逻辑位移)
- `AShr` → `Asr` (右算术位移)

### 3. 位操作完成 (优先级：中)

**需要实现的函数**:
```moonbit
fn i32_not_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i64_not_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
```

**实现模板**:
```moonbit
fn i32_not_mir_to_aarch64(
  inst : @MoonMIR.Instruction,
) -> Array[AArch64Asm] raise MIRToAArch64Error {
  guard inst is { opcode: IUnary(Not, 32), .. } else {
    println("Compiler ICE: i32_not_mir_to_aarch64 called with non-i32 not instruction: \{inst}")
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Mvn32(dst, src1)]  // ARM64的mvn指令实现按位取反
    }
    _ => raise MIRToAArch64Error("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}
```

### 4. 比较操作完成 (优先级：高)

**需要实现的函数**:
```moonbit
fn cmp_eq_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn cmp_ne_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn cmp_lt_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn cmp_gt_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn cmp_ge_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn cmp_ltu_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn cmp_gtu_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn cmp_leu_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn cmp_geu_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
```

**实现模板**（参考已完成的`cmp_le_mir_to_aarch64`）:
```moonbit
fn cmp_eq_mir_to_aarch64(
  inst : @MoonMIR.Instruction,
) -> Array[AArch64Asm] raise MIRToAArch64Error {
  guard inst is { opcode: ICmp(Eq, _), .. } else {
    println("Compiler ICE: cmp_eq_mir_to_aarch64 called with non-eq instruction: \{inst}")
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [IRegister(r1), IRegister(r2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Cmp64(src1, src2), Cset(dst, "eq")]  // 使用eq条件码
    }
    { defs: [IRegister(d)], uses: [IRegister(r1), Imm(i2)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let src1 = Reg::from_mir_reg(r1)
      [Cmp64Imm(src1, i2.to_int()), Cset(dst, "eq")]
    }
    _ => raise MIRToAArch64Error("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}
```

**ARM64条件码映射**:
- `Eq` → `"eq"` (相等)
- `Ne` → `"ne"` (不相等)
- `Lt` → `"lt"` (有符号小于)
- `Gt` → `"gt"` (有符号大于)
- `Le` → `"le"` (有符号小于等于)
- `Ge` → `"ge"` (有符号大于等于)
- `Ltu` → `"lo"` (无符号小于)
- `Gtu` → `"hi"` (无符号大于)
- `Leu` → `"ls"` (无符号小于等于)
- `Geu` → `"hs"` (无符号大于等于)

### 5. 内存操作完成 (优先级：中)

**需要实现的函数**:
```moonbit
fn i8_load_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i16_load_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i8_store_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i16_store_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
```

**实现模板**（参考已完成的`i32_load_mir_to_aarch64`）:
```moonbit
fn i8_load_mir_to_aarch64(
  inst : @MoonMIR.Instruction,
) -> Array[AArch64Asm] raise MIRToAArch64Error {
  guard inst is { opcode: ILoad(8), .. } else {
    println("Compiler ICE: i8_load_mir_to_aarch64 called with non-i8 load instruction: \{inst}")
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [Mem(base, offset)], .. } => {
      let dst = Reg::from_mir_reg(d)
      let base = Reg::from_mir_reg(base)
      let mem = Mem::{ base, offset }
      [Ldrb(dst, mem)]  // 加载字节，零扩展
    }
    _ => raise MIRToAArch64Error("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}
```

**内存指令映射**:
- 8位load → `Ldrb` (字节加载，零扩展) 或 `Ldrsb` (字节加载，符号扩展)
- 16位load → `Ldrh` (半字加载，零扩展) 或 `Ldrsh` (半字加载，符号扩展)
- 8位store → `Strb`
- 16位store → `Strh`

### 6. 分支操作完成 (优先级：高)

**需要实现的函数**:
```moonbit
fn branch_eq_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn branch_ne_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn branch_lt_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn branch_ge_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn branch_gt_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn branch_ltu_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn branch_geu_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn branch_leu_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn branch_gtu_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
```

**实现模板**（参考已完成的`branch_le_mir_to_aarch64`）:
```moonbit
fn branch_eq_mir_to_aarch64(
  inst : @MoonMIR.Instruction,
) -> Array[AArch64Asm] raise MIRToAArch64Error {
  guard inst is { opcode: Branch(Beq), .. } else {
    println("Compiler ICE: branch_eq_mir_to_aarch64 called with non-beq instruction: \{inst}")
    panic()
  }
  match inst {
    {
      defs: [],
      uses: [IRegister(r1), IRegister(r2), Label(true_label), Label(false_label)],
      ..,
    } => {
      let src1 = Reg::from_mir_reg(r1)
      let src2 = Reg::from_mir_reg(r2)
      [Cmp64(src1, src2), Beq(true_label), B(false_label)]
    }
    _ => raise MIRToAArch64Error("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}
```

### 7. 浮点操作 (优先级：低-中)

**需要实现的所有浮点函数**:
```moonbit
// 浮点算术
fn f32_add_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f64_add_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f32_sub_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f64_sub_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f32_mul_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f64_mul_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f32_div_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f64_div_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f32_neg_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f64_neg_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]

// 浮点比较
fn f32_cmp_eq_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f64_cmp_eq_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
// ... 其他比较操作

// 浮点内存操作
fn f32_load_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f64_load_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f32_store_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f64_store_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]

// 浮点移动
fn f32_move_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f64_move_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f32_movei_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn f64_movei_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i32_movef_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
fn i64_movef_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
```

**浮点实现模板**:
```moonbit
fn f64_add_mir_to_aarch64(
  inst : @MoonMIR.Instruction,
) -> Array[AArch64Asm] raise MIRToAArch64Error {
  guard inst is { opcode: FBinary(FAdd, 64), .. } else {
    println("Compiler ICE: f64_add_mir_to_aarch64 called with non-f64 add instruction: \{inst}")
    panic()
  }
  match inst {
    { defs: [FRegister(d)], uses: [FRegister(r1), FRegister(r2)], .. } => {
      let dst = FReg::from_mir_freg(d)  // 需要使用FReg::from_mir_freg
      let src1 = FReg::from_mir_freg(r1)
      let src2 = FReg::from_mir_freg(r2)
      [FaddD(dst, src1, src2)]  // 双精度浮点加法
    }
    _ => raise MIRToAArch64Error("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}
```

### 8. 类型转换操作 (优先级：中)

**需要实现的函数**:
```moonbit
fn cast_mir_to_aarch64(
  inst : @MoonMIR.Instruction,
  cast_op : @MoonMIR.CastOpCode,
) -> Array[AArch64Asm] raise MIRToAArch64Error
```

**参考RISC-V实现**:
查看`riscv/Convert.mbt`中的`cast_mir_to_riscv`函数，它处理各种类型转换：
- 零扩展 (ZExt)
- 符号扩展 (SExt)  
- 截断 (Trunc)
- 浮点转换 (FPToSI, SIToFP, FPExt, FPTrunc)

### 9. 地址加载操作 (优先级：低)

**需要实现的函数**:
```moonbit
fn loadaddr_mir_to_aarch64(inst : @MoonMIR.Instruction) -> Array[AArch64Asm]
```

**实现模板**:
```moonbit
fn loadaddr_mir_to_aarch64(
  inst : @MoonMIR.Instruction,
) -> Array[AArch64Asm] raise MIRToAArch64Error {
  guard inst is { opcode: LoadAddr, .. } else {
    println("Compiler ICE: loadaddr_mir_to_aarch64 called with non-loadaddr instruction: \{inst}")
    panic()
  }
  match inst {
    { defs: [IRegister(d)], uses: [Label(label)], .. } => {
      let dst = Reg::from_mir_reg(d)
      // ARM64使用adrp + add的组合来加载地址
      [Adrp(dst, label), AddLo12(dst, dst, label)]
    }
    _ => raise MIRToAArch64Error("Error: Unsupported MoonMIR instruction: \{inst}")
  }
}
```

## 🧪 测试策略

### 1. 单元测试
为每个新实现的函数创建测试：
```bash
# 测试逻辑运算
moon run mbtcc -- --target=aarch64 --file ctest/test_that_uses_or.c
moon run mbtcc -- --target=aarch64 --file ctest/test_that_uses_xor.c

# 测试位移运算
moon run mbtcc -- --target=aarch64 --file ctest/test_that_uses_shifts.c

# 测试比较操作
moon run mbtcc -- --target=aarch64 --file ctest/test_with_various_comparisons.c
```

### 2. 回归测试
确保新功能不破坏现有功能：
```bash
# 这些应该继续工作
moon run mbtcc -- --target=aarch64 --file ctest/simple_add.c
moon run mbtcc -- --target=aarch64 --file ctest/simple_fib.c
```

### 3. 对比测试
与RISC-V输出对比，确保逻辑正确：
```bash
# RISC-V输出
moon run mbtcc -- --file test.c -o test_riscv.s

# ARM64输出  
moon run mbtcc -- --target=aarch64 --file test.c -o test_arm64.s

# 比较两个文件的逻辑结构
```

## 🐛 调试技巧

### 1. 查看MoonMIR中间表示
```bash
moon run mbtcc -- --target=aarch64 --file test.c --stop-after=PostRA
```

### 2. 使用详细输出
```bash
moon run mbtcc -- --target=aarch64 --file test.c --print-all
```

### 3. 编译错误处理
- 所有TODO函数都会抛出明确的错误信息
- 根据错误信息定位需要实现的具体函数
- 使用`println`调试输出来理解指令结构

### 4. 参考现有实现
- RISC-V实现: `riscv/Convert.mbt`
- 已完成的ARM64函数: 如`i32_add_mir_to_aarch64`

## 📚 参考资料

### ARM64指令参考
- [ARM Developer Documentation](https://developer.arm.com/documentation/)
- [ARM64 Instruction Set Reference](https://developer.arm.com/documentation/ddi0596/)

### MoonMIR架构理解
- 查看`Operand.mbt`了解操作数类型
- 查看`OpCode.mbt`了解操作码定义
- 查看`Instruction.mbt`了解指令结构

### 代码风格
- 遵循现有代码的命名约定
- 每个函数都包含guard检查和错误处理
- 使用模式匹配处理不同的指令变体

## 🎯 优先级建议

1. **立即执行**（影响基本功能）:
   - 逻辑运算完成
   - 比较操作完成
   - 分支操作完成

2. **短期目标**（提升功能完整性）:
   - 位移操作完成
   - 位操作完成
   - 内存操作完成

3. **中期目标**（支持更复杂程序）:
   - 类型转换操作
   - 基础浮点操作

4. **长期目标**（完整功能）:
   - 完整浮点支持
   - 地址加载操作
   - 性能优化

## ✅ 完成检查清单

当你完成每个任务时，可以使用这个检查清单：

- [ ] 函数实现完成，没有TODO标记
- [ ] 编译通过，没有语法错误
- [ ] 至少一个测试用例通过
- [ ] 与RISC-V输出逻辑对比正确
- [ ] 错误处理完善
- [ ] 代码风格一致

## 🔄 提交指南

1. **小步提交**: 每完成一个操作类型就提交一次
2. **描述性提交信息**: 如"Implement ARM64 logical operations (or, xor)"
3. **包含测试**: 每个提交都应该包含相应的测试验证
4. **更新文档**: 完成后更新这个TODO文档，标记已完成的项目

---

这份指南应该为下一个开发者提供了充足的信息来继续完成ARM64后端的开发。每个部分都包含了具体的实现模板和参考，应该能够大大降低开发的复杂性。