#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import subprocess
import sys
import argparse

# ==============================================================================
# Configuration
# ==============================================================================

# Test cases for each architecture
RISCV64_TESTS = [
    "simple_ret", "simple_add", "simple_fib", "bin_int", "fib", "if", "for", 
    "while", "while2", "nested_while", "branch", "many_args", "order_args", 
    "ptr", "struct", "array", "heap_arr", "arr_struct", "matrix",
    "linked_list", "bst", "hash_table", "binary_search", "bubble_sort", 
    "merge_sort", "quick_sort", "heap_sort", "dijkstra", "lcs", "dsu"
]

AARCH64_TESTS = [
    "simple_ret", "simple_add", "simple_fib", "bin_int", "fib", "if", "for",
    "while", "while2", "nested_while", "branch", "many_args", "order_args",
    "ptr", "struct", "array", "heap_arr", "arr_struct", "matrix", 
    "linked_list", "bst", "hash_table", "queue", "binary_search", 
    "bubble_sort", "merge_sort", "quick_sort", "heap_sort", "dijkstra", 
    "lcs", "dsu", "prim"
]

# C source directory
C_SOURCE_DIR = "ctest"
RUNTIME_C = "runtime.c"

# ==============================================================================
# Style and Formatting
# ==============================================================================

class Style:
    """为终端输出添加颜色和Emoji的辅助类"""
    RESET = "\033[0m"
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    MAGENTA = "\033[95m"

    PASSED = "✅"
    FAILED = "❌"
    INFO = "ℹ️"
    COMPILE = "👨‍💻"
    LINK = "🔗"
    RUN = "🚀"
    CLEAN = "🧹"
    WARN = "⚠️"
    ARROW = "👉"
    SUMMARY = "📊"
    CELEBRATE = "🎉"

# ==============================================================================
# Core Test Logic
# ==============================================================================

def run_single_test(c_file_path: str, target: str) -> bool:
    """
    对单个测试用例执行完整的编译、运行和验证流程，保留原始脚本的详细输出。
    返回 True 表示测试通过，False 表示失败。
    """
    base_name = os.path.splitext(os.path.basename(c_file_path))[0]
    print(f"\n{Style.BLUE}===== Running Test for: {base_name} ({target}) ====={Style.RESET}")

    # 1. 检查C源文件是否存在
    print(f"{Style.INFO} Checking for source file: {c_file_path}...")
    if not os.path.exists(c_file_path):
        print(f"{Style.RED}{Style.FAILED} Error: File '{c_file_path}' Not Found. Skipping...{Style.RESET}")
        return False

    s_file = f"{base_name}.s"
    moon_executable = f"{base_name}.moon"
    std_executable = f"{base_name}.std"
    
    cleanup_files = [s_file, moon_executable, std_executable]

    try:
        # 2. 编译C到目标架构汇编
        print(f"{Style.COMPILE} Compiling to {target} assembly ({s_file})...")
        compile_cmd = ["moon", "run", "mbtcc", "--", "--file", c_file_path, f"--target={target}", "-o", s_file]
        result = subprocess.run(compile_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"{Style.RED}{Style.FAILED} Error: Compilation to {target} assembly failed for '{base_name}.c'.{Style.RESET}")
            if result.stdout or result.stderr:
                print(f"{Style.YELLOW}{Style.ARROW} mbtcc output:{Style.RESET}\n{result.stdout}{result.stderr}")
            return False

        # 3. 使用对应工具链链接.s文件生成目标可执行文件
        print(f"{Style.LINK} Assembling {target} executable with toolchain ({moon_executable})...")
        if target == 'riscv64':
            assembler_cmd = ["riscv64-unknown-elf-gcc", "-o", moon_executable, s_file, RUNTIME_C, "-lm"]
        else: # aarch64
            assembler_cmd = ["clang", "-o", moon_executable, s_file, RUNTIME_C, "-lm"]
        
        result = subprocess.run(assembler_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"{Style.RED}{Style.FAILED} Error: Toolchain failed while assembling '{s_file}'.{Style.RESET}")
            if result.stdout or result.stderr:
                print(f"{Style.YELLOW}{Style.ARROW} Toolchain output:{Style.RESET}\n{result.stdout}{result.stderr}")
            return False

        # 4. 直接使用clang编译.c文件生成标准可执行文件用于比对
        print(f"{Style.LINK} Compiling standard executable with Clang ({std_executable})...")
        clang_cmd = ["clang", "-o", std_executable, c_file_path, RUNTIME_C, "-lm"]
        result = subprocess.run(clang_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"{Style.RED}{Style.FAILED} Error: Clang failed to compile the source file '{base_name}.c'.{Style.RESET}")
            if result.stdout or result.stderr:
                print(f"{Style.YELLOW}{Style.ARROW} Clang output:{Style.RESET}\n{result.stdout}{result.stderr}")
            return False

        # 5. 运行两个可执行文件并比较结果
        print(f"{Style.RUN} Executing both versions...")
        if target == 'riscv64':
            moon_run_cmd = ["spike", "pk", f"./{moon_executable}"]
        else: # aarch64
            moon_run_cmd = [f"./{moon_executable}"]
        
        std_run_cmd = [f"./{std_executable}"]

        moon_result = subprocess.run(moon_run_cmd, capture_output=True, text=True)
        std_result = subprocess.run(std_run_cmd, capture_output=True, text=True)

        ret_ok = moon_result.returncode == std_result.returncode
        stdout_ok = moon_result.stdout == std_result.stdout
        stderr_ok = moon_result.stderr == std_result.stderr

        if ret_ok and stdout_ok and stderr_ok:
            print(f"{Style.GREEN}{Style.PASSED} Test '{c_file_path}' PASSED! Outputs match perfectly.{Style.RESET}")
            return True
        else:
            print(f"{Style.RED}{Style.FAILED} Test '{c_file_path}' FAILED! Outputs do not match.{Style.RESET}")
            if not ret_ok:
                runner = 'spike' if target == 'riscv64' else 'moon'
                print(f"{Style.YELLOW}  - Return codes differ: [{runner}: {moon_result.returncode}] vs [std: {std_result.returncode}]{Style.RESET}")
            if not stdout_ok:
                print(f"{Style.YELLOW}  - Standard outputs differ.{Style.RESET}")
                # Uncomment for detailed diff
                # print(f"{Style.CYAN}--- Moon Output ---\n{moon_result.stdout}{Style.RESET}")
                # print(f"{Style.CYAN}--- Standard Output ---\n{std_result.stdout}{Style.RESET}")
            if not stderr_ok:
                print(f"{Style.YELLOW}  - Standard errors differ.{Style.RESET}")
            return False

    finally:
        # 6. 清理生成的所有文件
        print(f"{Style.CLEAN} Cleaning up generated files for '{base_name}'...")
        for f in cleanup_files:
            if os.path.exists(f):
                try:
                    os.remove(f)
                except OSError as e:
                    print(f"{Style.RED}{Style.WARN} Warning: Could not remove file '{f}': {e}{Style.RESET}")

def run_test_suite(target: str, tests: list[str]) -> list:
    """Runs a collection of tests for a given target."""
    print(f"\n{Style.MAGENTA}=========================================={Style.RESET}")
    print(f"{Style.MAGENTA}{Style.SUMMARY} Starting Test Suite for {target.upper()}{Style.RESET}")
    print(f"{Style.MAGENTA}=========================================={Style.RESET}")
    failed_tests = []
    for test_name in tests:
        c_file_path = os.path.join(C_SOURCE_DIR, f"{test_name}.c")
        if not run_single_test(c_file_path, target):
            failed_tests.append(test_name)
    return failed_tests

# ==============================================================================
# Main Execution
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Moonbit-C Test Runner for RISC-V and AArch64.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "-f", "--file",
        type=str,
        help="Run a single test on a specific C file.\nDefaults to aarch64 target unless --target is specified."
    )
    parser.add_argument(
        "--target",
        type=str,
        choices=["riscv64", "aarch64"],
        help="Specify the target architecture to test.\n- 'riscv64': Run all RISC-V tests.\n- 'aarch64': Run all AArch64 tests.\nIf used with -f, specifies the target for that single file."
    )

    args = parser.parse_args()

    if not os.path.exists(RUNTIME_C):
        print(f"{Style.RED}{Style.FAILED} Critical Error: '{RUNTIME_C}' not found. Aborting.{Style.RESET}")
        sys.exit(1)

    failed_summary = {}

    if args.file:
        # Run a single file test
        target = args.target if args.target else "aarch64"
        if not run_single_test(args.file, target):
            print(f"\nSummary: Test for {args.file} on {target} failed.")
        else:
            print(f"\nSummary: Test for {args.file} on {target} passed.")

    elif args.target:
        # Run all tests for a specific target
        if args.target == "riscv64":
            failed_summary["riscv64"] = run_test_suite("riscv64", RISCV64_TESTS)
        elif args.target == "aarch64":
            failed_summary["aarch64"] = run_test_suite("aarch64", AARCH64_TESTS)
    
    else:
        # Run all tests for all targets
        failed_summary["riscv64"] = run_test_suite("riscv64", RISCV64_TESTS)
        failed_summary["aarch64"] = run_test_suite("aarch64", AARCH64_TESTS)

    # Print summary for suite runs
    if not args.file:
        print(f"\n{Style.MAGENTA}=========================================={Style.RESET}")
        print(f"{Style.MAGENTA}{Style.SUMMARY} Test Suite Summary{Style.RESET}")
        print(f"{Style.MAGENTA}=========================================={Style.RESET}")
        all_passed = True
        total_tests = 0
        total_failed = 0

        for target, failed_tests in failed_summary.items():
            suite_tests = RISCV64_TESTS if target == 'riscv64' else AARCH64_TESTS
            passed_count = len(suite_tests) - len(failed_tests)
            total_tests += len(suite_tests)
            total_failed += len(failed_tests)

            if failed_tests:
                all_passed = False
                print(f"\n{Style.YELLOW}Suite {target.upper()}: Passed: {passed_count}/{len(suite_tests)}{Style.RESET}")
                print(f"{Style.RED}The following tests failed for {target.upper()}:{Style.RESET}")
                for test in failed_tests:
                    print(f"  {Style.FAILED} {test}")
            else:
                print(f"\n{Style.GREEN}{Style.PASSED} All {len(suite_tests)} tests passed for {target.upper()}!{Style.RESET}")
        
        print("------------------------------------------")
        if all_passed:
            print(f"{Style.GREEN}{Style.CELEBRATE} All {total_tests} tests passed across all suites! {Style.RESET}")
        else:
            print(f"{Style.RED}{Style.FAILED} Total failed tests: {total_failed}. See details above.{Style.RESET}")
            sys.exit(1)

if __name__ == "__main__":
    main()