#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import subprocess
import sys

# --- 配置区 ---

# 测试用例的基础名称列表
TEST_CASES = [
    "simple_ret", "simple_add", "simple_fib", "bin_int", 
    "fib", "if", "for", "while", "while2", "nested_while", 
    "branch", "many_args", "order_args", "ptr", "struct", 
    "array", "heap_arr", "arr_struct", "matrix", 
    "linked_list", "bst",
    "binary_search", "bubble_sort", "merge_sort", "quick_sort",
    "dijkstra",
]

# C语言源文件所在的目录
C_SOURCE_DIR = "ctest"

# 运行时支持文件
RUNTIME_C = "runtime.c"

# 目标架构
TARGET_ARCH = "aarch64"

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
    print(f"\n{Style.BLUE}===== Running Test for: {base_name} ({TARGET_ARCH}) ====={Style.RESET}")

    c_file = f"{base_name}.c"
    c_file_path = os.path.join(C_SOURCE_DIR, c_file)
    
    # 定义临时文件名
    s_file = f"{base_name}.s"
    moon_executable = f"{base_name}.moon" # 编译器生成汇编，然后链接得到的可执行文件
    std_executable = f"{base_name}.std"   # Clang直接编译C代码得到的可执行文件
    
    try:
        # 1. 检查C源文件是否存在
        print(f"{Style.INFO} Checking for source file: {c_file_path}...")
        if not os.path.exists(c_file_path):
            print(f"{Style.RED}{Style.FAILED} Error: Source file '{c_file_path}' was not found. Skipping...{Style.RESET}")
            return False

        # 2. 编译C到AArch64汇编
        print(f"{Style.COMPILE} Compiling to {TARGET_ARCH} assembly ({s_file})...")
        # 核心修改点A：添加 --target=aarch64
        cmd_aarch64_compile = ["moon", "run", "mbtcc", "--", "--file", c_file_path, f"--target={TARGET_ARCH}", "-o", s_file]
        result = subprocess.run(cmd_aarch64_compile, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"{Style.RED}{Style.FAILED} Error: Compilation to {TARGET_ARCH} assembly failed for '{c_file}'.{Style.RESET}")
            if result.stdout or result.stderr:
                print(f"{Style.YELLOW}{Style.ARROW} mbtcc output:{Style.RESET}\n{result.stdout}{result.stderr}")
            return False
        
        # 3. 使用clang链接.s文件生成目标可执行文件
        print(f"{Style.LINK} Assembling {TARGET_ARCH} executable with Clang ({moon_executable})...")
        # 核心修改点B：使用clang链接
        cmd_clang_link = ["clang", "-o", moon_executable, s_file, RUNTIME_C, "-lm"]
        result = subprocess.run(cmd_clang_link, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"{Style.RED}{Style.FAILED} Error: Clang failed while assembling '{s_file}'.{Style.RESET}")
            if result.stdout or result.stderr:
                print(f"{Style.YELLOW}{Style.ARROW} Toolchain output:{Style.RESET}\n{result.stdout}{result.stderr}")
            return False

        # 4. 直接使用clang编译.c文件生成标准可执行文件
        print(f"{Style.LINK} Compiling standard executable with Clang ({std_executable})...")
        cmd_clang_std = ["clang", "-o", std_executable, c_file_path, RUNTIME_C, "-lm"]
        result = subprocess.run(cmd_clang_std, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"{Style.RED}{Style.FAILED} Error: Clang failed to compile the source file '{c_file}'.{Style.RESET}")
            if result.stdout or result.stderr:
                print(f"{Style.YELLOW}{Style.ARROW} Clang output:{Style.RESET}\n{result.stdout}{result.stderr}")
            return False

        # 5. 运行两个可执行文件并比较结果
        print(f"{Style.RUN} Executing both versions...")
        # 核心修改点C：直接运行目标可执行文件
        moon_result = subprocess.run([f"./{moon_executable}"], capture_output=True, text=True)
        std_result = subprocess.run([f"./{std_executable}"], capture_output=True, text=True)

        ret_ok = moon_result.returncode == std_result.returncode
        stdout_ok = moon_result.stdout == std_result.stdout
        stderr_ok = moon_result.stderr == std_result.stderr

        if ret_ok and stdout_ok and stderr_ok:
            print(f"{Style.GREEN}{Style.PASSED} Test '{c_file_path}' PASSED! Outputs match perfectly.{Style.RESET}")
            return True
        else:
            print(f"{Style.RED}{Style.FAILED} Test '{c_file_path}' FAILED! Outputs do not match.{Style.RESET}")
            if not ret_ok:
                print(f"{Style.YELLOW}  - Return codes differ: [moon: {moon_result.returncode}] vs [std: {std_result.returncode}]{Style.RESET}")
            if not stdout_ok:
                print(f"{Style.YELLOW}  - Standard outputs differ.{Style.RESET}")
            if not stderr_ok:
                print(f"{Style.YELLOW}  - Standard errors differ.{Style.RESET}")
            
            # 打印详细输出，方便调试
            print(f"{Style.CYAN}--- Moon Output ---{Style.RESET}")
            print(moon_result.stdout)
            print(f"{Style.CYAN}--- Standard Output ---{Style.RESET}")
            print(std_result.stdout)
            
            return False

    finally:
        # 6. 清理生成的所有文件
        print(f"{Style.CLEAN} Cleaning up generated files for '{base_name}'...")
        files_to_remove = [s_file, moon_executable, std_executable]
        for f in files_to_remove:
            if os.path.exists(f):
                try:
                    os.remove(f)
                except OSError as e:
                    print(f"{Style.RED}{Style.WARN} Warning: Could not remove file '{f}': {e}{Style.RESET}")


def main():
    """脚本主入口，运行所有测试并报告总结"""
    print(f"{Style.GREEN}Starting the {TARGET_ARCH} test suite...{Style.RESET}")
    if not os.path.exists(RUNTIME_C):
        print(f"{Style.RED}{Style.FAILED} Critical Error: '{RUNTIME_C}' not found. Aborting tests.{Style.RESET}")
        sys.exit(1)
    
    # 检查当前系统是否支持直接运行 aarch64 可执行文件
    # 注意：这个检查并非必需，但能给用户更好的提示
    if os.uname().machine not in ['aarch64', 'arm64']:
         print(f"{Style.WARN}{Style.YELLOW}Warning: Current machine architecture is not native {TARGET_ARCH} ({os.uname().machine}). Direct execution might fail unless QEMU or similar emulation is set up.{Style.RESET}")
    
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
    print(f"{Style.MAGENTA}{Style.SUMMARY} {TARGET_ARCH} Test Suite Summary{Style.RESET}")
    print(f"{Style.MAGENTA}=========================================={Style.RESET}")

    if failed_count == 0:
        print(f"{Style.GREEN}{Style.CELEBRATE} All {total_tests} tests passed for {TARGET_ARCH}! {Style.RESET}")
    else:
        print(f"{Style.YELLOW}Tested: {total_tests}, Passed: {passed_count}, Failed: {failed_count}{Style.RESET}")
        print(f"\n{Style.RED}The following tests failed:{Style.RESET}")
        for case_name in failed_cases:
            print(f"  {Style.FAILED} {case_name}")

if __name__ == "__main__":
    main()
