#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import subprocess
import sys
import argparse
from pathlib import Path
from dataclasses import dataclass
from typing import List, Optional

# ==============================================================================
# Configuration
# ==============================================================================

C_TEST_DIR = "real_tests/C"
MINIMOONBIT_TEST_DIR = "real_tests/MiniMoonBit"
MINIMOONBIT_ANS_DIR = "real_tests/MiniMoonBitAns"
C_RUNTIME = "real_tests/cruntime.c"
MINIMOONBIT_RUNTIME = "real_tests/mbtruntime.c"

# ==============================================================================
# Data Structures
# ==============================================================================

@dataclass
class FailureInfo:
    """记录测试失败的详细信息"""
    test_file: str
    test_type: str  # "c" or "minimoonbit"
    target: str     # "riscv64" or "aarch64"
    reason: str     # "compilation", "assembly", "output_mismatch", etc.
    details: str    # 详细错误信息

# 全局失败列表
failed_tests: List[FailureInfo] = []

# ==============================================================================
# Test Logic
# ==============================================================================

def run_c_test(c_file: str, target: str) -> bool:
    """测试单个C文件"""
    base_name = Path(c_file).stem
    print(f"[C/{target}] Testing {base_name}...", end=" ")
    
    s_file = f"{base_name}.s"
    moon_exec = f"{base_name}.moon"
    std_exec = f"{base_name}.std"
    
    cleanup_files = [s_file, moon_exec, std_exec]
    
    try:
        # 1. 编译到汇编
        compile_cmd = ["moon", "run", "mbtcc", "--", "--file", c_file, f"--target={target}", "-o", s_file]
        result = subprocess.run(compile_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print("FAIL (compilation)")
            error_msg = result.stderr.strip() if result.stderr else result.stdout.strip()
            failed_tests.append(FailureInfo(
                test_file=c_file,
                test_type="C",
                target=target,
                reason="compilation",
                details=error_msg[:500]  # 限制长度
            ))
            return False
        
        # 2. 汇编链接
        if target == 'riscv64':
            asm_cmd = ["riscv64-unknown-elf-gcc", "-o", moon_exec, s_file, C_RUNTIME, "-lm"]
        else:  # aarch64
            asm_cmd = ["clang", "-o", moon_exec, s_file, C_RUNTIME, "-lm"]
        
        result = subprocess.run(asm_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print("FAIL (assembly)")
            error_msg = result.stderr.strip() if result.stderr else "Assembly linking failed"
            failed_tests.append(FailureInfo(
                test_file=c_file,
                test_type="C",
                target=target,
                reason="assembly",
                details=error_msg[:500]
            ))
            return False
        
        # 3. 标准编译器编译
        clang_cmd = ["clang", "-o", std_exec, c_file, C_RUNTIME, "-lm"]
        result = subprocess.run(clang_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print("FAIL (standard compilation)")
            error_msg = result.stderr.strip() if result.stderr else "Standard compilation failed"
            failed_tests.append(FailureInfo(
                test_file=c_file,
                test_type="C",
                target=target,
                reason="standard_compilation",
                details=error_msg[:500]
            ))
            return False
        
        # 4. 运行并比较
        if target == 'riscv64':
            moon_run_cmd = ["spike", "pk", f"./{moon_exec}"]
        else:
            moon_run_cmd = [f"./{moon_exec}"]
        
        moon_result = subprocess.run(moon_run_cmd, capture_output=True, text=True)
        std_result = subprocess.run([f"./{std_exec}"], capture_output=True, text=True)
        
        if (moon_result.returncode == std_result.returncode and
            moon_result.stdout == std_result.stdout and
            moon_result.stderr == std_result.stderr):
            print("PASS")
            return True
        else:
            print("FAIL (output mismatch)")
            details_parts = []
            if moon_result.returncode != std_result.returncode:
                details_parts.append(f"Return code: {moon_result.returncode} vs {std_result.returncode}")
            if moon_result.stdout != std_result.stdout:
                details_parts.append(f"Expected stdout: {std_result.stdout.strip()!r}")
                details_parts.append(f"Got stdout: {moon_result.stdout.strip()!r}")
            if moon_result.stderr != std_result.stderr:
                details_parts.append(f"Expected stderr: {std_result.stderr.strip()!r}")
                details_parts.append(f"Got stderr: {moon_result.stderr.strip()!r}")
            
            details = " | ".join(details_parts)
            failed_tests.append(FailureInfo(
                test_file=c_file,
                test_type="C",
                target=target,
                reason="output_mismatch",
                details=details[:500]
            ))
            return False
    
    finally:
        # 清理
        for f in cleanup_files:
            if os.path.exists(f):
                try:
                    os.remove(f)
                except OSError:
                    pass


def run_minimoonbit_test(mbt_file: str, target: str) -> bool:
    """测试单个MiniMoonbit文件"""
    base_name = Path(mbt_file).stem
    print(f"[MBT/{target}] Testing {base_name}...", end=" ")
    
    s_file = f"{base_name}.s"
    exec_file = f"{base_name}.exe"
    ans_file = os.path.join(MINIMOONBIT_ANS_DIR, f"{base_name}.ans")
    
    cleanup_files = [s_file, exec_file]
    
    try:
        # 1. 检查答案文件
        if not os.path.exists(ans_file):
            print("SKIP (no answer file)")
            return True
        
        with open(ans_file, 'r') as f:
            expected_output = f.read()
        
        # 2. 编译到汇编
        compile_cmd = ["moon", "run", "minimbt", "--", "--file", mbt_file, f"--target={target}", "-o", s_file]
        result = subprocess.run(compile_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print("FAIL (compilation)")
            error_msg = result.stderr.strip() if result.stderr else result.stdout.strip()
            failed_tests.append(FailureInfo(
                test_file=mbt_file,
                test_type="MiniMoonBit",
                target=target,
                reason="compilation",
                details=error_msg[:500]
            ))
            return False
        
        # 3. 汇编链接
        if target == 'riscv64':
            asm_cmd = ["riscv64-unknown-elf-gcc", "-o", exec_file, s_file, MINIMOONBIT_RUNTIME, "-lm"]
        else:  # aarch64
            asm_cmd = ["clang", "-o", exec_file, s_file, MINIMOONBIT_RUNTIME, "-lm"]
        
        result = subprocess.run(asm_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print("FAIL (assembly)")
            error_msg = result.stderr.strip() if result.stderr else "Assembly linking failed"
            failed_tests.append(FailureInfo(
                test_file=mbt_file,
                test_type="MiniMoonBit",
                target=target,
                reason="assembly",
                details=error_msg[:500]
            ))
            return False
        
        # 4. 运行并比较
        if target == 'riscv64':
            run_cmd = ["spike", "pk", f"./{exec_file}"]
        else:
            run_cmd = [f"./{exec_file}"]
        
        result = subprocess.run(run_cmd, capture_output=True, text=True)
        
        if result.stdout == expected_output:
            print("PASS")
            return True
        else:
            print("FAIL (output mismatch)")
            details = f"Expected: {expected_output.strip()!r} | Got: {result.stdout.strip()!r}"
            failed_tests.append(FailureInfo(
                test_file=mbt_file,
                test_type="MiniMoonBit",
                target=target,
                reason="output_mismatch",
                details=details[:500]
            ))
            return False
    
    finally:
        # 清理
        for f in cleanup_files:
            if os.path.exists(f):
                try:
                    os.remove(f)
                except OSError:
                    pass


def run_test_suite(test_type: str, target: str) -> tuple:
    """运行测试套件"""
    if test_type == "c":
        test_dir = C_TEST_DIR
        test_fn = run_c_test
        ext = ".c"
    else:  # minimoonbit
        test_dir = MINIMOONBIT_TEST_DIR
        test_fn = run_minimoonbit_test
        ext = ".mbt"
    
    if not os.path.exists(test_dir):
        print(f"Warning: Directory '{test_dir}' does not exist. Skipping.")
        return 0, 0
    
    # 获取所有测试文件
    test_files = sorted([f for f in os.listdir(test_dir) if f.endswith(ext)])
    
    if not test_files:
        print(f"No test files found in '{test_dir}'.")
        return 0, 0
    
    passed = 0
    failed = 0
    
    for test_file in test_files:
        file_path = os.path.join(test_dir, test_file)
        if test_fn(file_path, target):
            passed += 1
        else:
            failed += 1
    
    return passed, failed


def print_failure_report():
    """打印详细的失败报告"""
    if not failed_tests:
        return
    
    print("\n" + "="*80)
    print("FAILURE REPORT")
    print("="*80)
    
    # 按类型和架构分组
    by_type = {}
    for failure in failed_tests:
        key = (failure.test_type, failure.target)
        if key not in by_type:
            by_type[key] = []
        by_type[key].append(failure)
    
    # 打印每个分组
    for (test_type, target), failures in sorted(by_type.items()):
        print(f"\n{test_type} / {target} ({len(failures)} failures):")
        print("-" * 80)
        
        # 按失败原因分组
        by_reason = {}
        for failure in failures:
            if failure.reason not in by_reason:
                by_reason[failure.reason] = []
            by_reason[failure.reason].append(failure)
        
        for reason, fails in sorted(by_reason.items()):
            print(f"\n  {reason.upper()} ({len(fails)} tests):")
            for fail in fails:
                test_name = Path(fail.test_file).stem
                print(f"    • {test_name}")
                if fail.details:
                    # 缩进详细信息
                    detail_lines = fail.details.split('\n')
                    for line in detail_lines[:3]:  # 最多显示3行
                        if line.strip():
                            print(f"      {line.strip()[:100]}")
                    if len(detail_lines) > 3:
                        print(f"      ... ({len(detail_lines) - 3} more lines)")
    
    print("\n" + "="*80)
    print(f"Total failures: {len(failed_tests)}")
    print("="*80)


# ==============================================================================
# Main
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(description="Simplified test runner for MoonMIR")
    parser.add_argument("--target", choices=["riscv64", "aarch64", "all"], 
                        default="all", help="Target architecture")
    parser.add_argument("--type", choices=["c", "minimoonbit", "all"],
                        default="all", help="Test type")
    parser.add_argument("-f", "--file", help="Test a single file")
    
    args = parser.parse_args()
    
    # 检查runtime文件
    if not os.path.exists(C_RUNTIME):
        print(f"Error: Runtime file '{C_RUNTIME}' not found.")
        sys.exit(1)
    
    # 单文件测试
    if args.file:
        targets = ["riscv64", "aarch64"] if args.target == "all" else [args.target]
        
        # 判断文件类型
        if args.file.endswith(".c"):
            test_fn = run_c_test
        elif args.file.endswith(".mbt"):
            test_fn = run_minimoonbit_test
        else:
            print("Error: File must be .c or .mbt")
            sys.exit(1)
        
        total_passed = 0
        total_failed = 0
        for target in targets:
            if test_fn(args.file, target):
                total_passed += 1
            else:
                total_failed += 1
        
        print(f"\nSummary: {total_passed} passed, {total_failed} failed")
        
        # 打印失败报告
        if total_failed > 0:
            print_failure_report()
        
        sys.exit(0 if total_failed == 0 else 1)
    
    # 测试套件
    targets = ["riscv64", "aarch64"] if args.target == "all" else [args.target]
    test_types = ["c", "minimoonbit"] if args.type == "all" else [args.type]
    
    total_passed = 0
    total_failed = 0
    
    for test_type in test_types:
        for target in targets:
            print(f"\n{'='*60}")
            print(f"Running {test_type.upper()} tests on {target.upper()}")
            print('='*60)
            
            passed, failed = run_test_suite(test_type, target)
            total_passed += passed
            total_failed += failed
            
            print(f"\n{test_type.upper()}/{target.upper()}: {passed} passed, {failed} failed")
    
    print(f"\n{'='*60}")
    print(f"OVERALL: {total_passed} passed, {total_failed} failed")
    print('='*60)
    
    # 打印失败报告
    if total_failed > 0:
        print_failure_report()
    
    sys.exit(0 if total_failed == 0 else 1)


if __name__ == "__main__":
    main()

