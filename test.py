#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import subprocess
import sys

# --- 配置区 ---

# 测试用例的基础名称列表
TEST_CASES = [
    "fib", "simple_add", "bin_int", "if", "for", "while", "while2", "branch",
    "many_args", "order_args", "ptr", "struct", "array", "binary_search",
    "heap_arr", "bubble_sort", "merge_sort", "quick_sort", "arr_struct"]

# C语言源文件所在的目录
C_SOURCE_DIR = "ctest"

# 运行时支持文件
RUNTIME_C = "runtime.c"

# --- 颜色和Emoji ---
class Style:
    """为终端输出添加颜色和Emoji的辅助类"""
    # 颜色
    RESET = "\033[0m"
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    MAGENTA = "\033[95m"

    # Emoji
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

def run_test(base_name: str) -> bool:
    """
    对单个测试用例执行完整的编译、运行和验证流程。
    返回 True 表示测试通过，False 表示失败。
    """
    print(f"\n{Style.BLUE}===== Running Test for: {base_name} ====={Style.RESET}")

    c_file = f"{base_name}.c"
    c_file_path = os.path.join(C_SOURCE_DIR, c_file)
    
    # 定义临时文件名
    s_file = f"{base_name}.s"
    moon_executable = f"{base_name}.moon"
    std_executable = f"{base_name}.std"
    
    try:
        # 1. 检查C源文件是否存在
        print(f"{Style.INFO} Checking for source file: {c_file_path}...")
        if not os.path.exists(c_file_path):
            print(f"{Style.RED}{Style.FAILED} Error: Source file '{c_file_path}' was not found. Skipping...{Style.RESET}")
            return False

        # 2. 编译C到RISC-V汇编
        print(f"{Style.COMPILE} Compiling to RISC-V assembly ({s_file})...")
        cmd_riscv = ["moon", "run", "mbtcc", "--", "--file", c_file_path, "-o", s_file]
        result = subprocess.run(cmd_riscv, capture_output=True, text=True)
        if result.returncode != 0 or result.stdout or result.stderr:
            print(f"{Style.RED}{Style.FAILED} Error: Compilation to RISC-V assembly failed for '{c_file}'.{Style.RESET}")
            if result.stdout or result.stderr:
                print(f"{Style.YELLOW}{Style.ARROW} mbtcc output:{Style.RESET}\n{result.stdout}{result.stderr}")
            return False
        
        # --- 步骤 3 已被移除 ---

        # 4. 使用riscv64-unknown-elf-gcc链接.s文件
        print(f"{Style.LINK} Assembling RISC-V executable ({moon_executable})...")
        cmd_gcc = ["riscv64-unknown-elf-gcc", "-o", moon_executable, s_file, RUNTIME_C, "-lm"]
        result = subprocess.run(cmd_gcc, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"{Style.RED}{Style.FAILED} Error: RISC-V GCC toolchain failed while assembling '{s_file}'.{Style.RESET}")
            if result.stdout or result.stderr:
                print(f"{Style.YELLOW}{Style.ARROW} Toolchain output:{Style.RESET}\n{result.stdout}{result.stderr}")
            return False

        # 5. 【修改】直接使用clang编译.c文件生成标准可执行文件
        print(f"{Style.LINK} Compiling standard executable with Clang ({std_executable})...")
        # 直接使用 c_file_path 替代之前的 ll_file
        cmd_clang = ["clang", "-o", std_executable, c_file_path, RUNTIME_C, "-lm"]
        result = subprocess.run(cmd_clang, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"{Style.RED}{Style.FAILED} Error: Clang failed to compile the source file '{c_file}'.{Style.RESET}")
            if result.stdout or result.stderr:
                print(f"{Style.YELLOW}{Style.ARROW} Clang output:{Style.RESET}\n{result.stdout}{result.stderr}")
            return False

        # 6. 运行两个可执行文件并比较结果
        print(f"{Style.RUN} Executing both versions...")
        spike_result = subprocess.run(["spike", "pk", moon_executable], capture_output=True, text=True)
        std_result = subprocess.run([f"./{std_executable}"], capture_output=True, text=True)

        ret_ok = spike_result.returncode == std_result.returncode
        stdout_ok = spike_result.stdout == std_result.stdout
        stderr_ok = spike_result.stderr == std_result.stderr

        if ret_ok and stdout_ok and stderr_ok:
            print(f"{Style.GREEN}{Style.PASSED} Test '{c_file_path}' PASSED! Outputs match perfectly.{Style.RESET}")
            return True
        else:
            print(f"{Style.RED}{Style.FAILED} Test '{c_file_path}' FAILED! Outputs do not match.{Style.RESET}")
            if not ret_ok:
                print(f"{Style.YELLOW}  - Return codes differ: [spike: {spike_result.returncode}] vs [std: {std_result.returncode}]{Style.RESET}")
            if not stdout_ok:
                print(f"{Style.YELLOW}  - Standard outputs differ.{Style.RESET}")
            if not stderr_ok:
                print(f"{Style.YELLOW}  - Standard errors differ.{Style.RESET}")
            return False

    finally:
        # 7. 【修改】清理生成的所有文件
        print(f"{Style.CLEAN} Cleaning up generated files for '{base_name}'...")
        # 移除了 ll_file
        files_to_remove = [s_file, moon_executable, std_executable]
        for f in files_to_remove:
            if os.path.exists(f):
                try:
                    os.remove(f)
                except OSError as e:
                    print(f"{Style.RED}{Style.WARN} Warning: Could not remove file '{f}': {e}{Style.RESET}")


def main():
    """脚本主入口，运行所有测试并报告总结"""
    print(f"{Style.GREEN}Starting the test suite...{Style.RESET}")
    if not os.path.exists(RUNTIME_C):
        print(f"{Style.RED}{Style.FAILED} Critical Error: '{RUNTIME_C}' not found. Aborting tests.{Style.RESET}")
        sys.exit(1)
    
    passed_cases = []
    failed_cases = []
    
    for test_name in TEST_CASES:
        if run_test(test_name):
            passed_cases.append(test_name)
        else:
            failed_cases.append(test_name)

    total_tests = len(TEST_CASES)
    passed_count = len(passed_cases)
    failed_count = len(failed_cases)

    print(f"\n{Style.MAGENTA}=========================================={Style.RESET}")
    print(f"{Style.MAGENTA}{Style.SUMMARY} Test Suite Summary{Style.RESET}")
    print(f"{Style.MAGENTA}=========================================={Style.RESET}")

    if failed_count == 0:
        print(f"{Style.GREEN}{Style.CELEBRATE} All {total_tests} tests passed! {Style.RESET}")
    else:
        print(f"{Style.YELLOW}Tested: {total_tests}, Passed: {passed_count}, Failed: {failed_count}{Style.RESET}")
        print(f"\n{Style.RED}The following tests failed:{Style.RESET}")
        for case_name in failed_cases:
            print(f"  {Style.FAILED} {case_name}")

if __name__ == "__main__":
    main()
