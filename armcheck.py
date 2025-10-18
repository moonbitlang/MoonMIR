#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import subprocess
import sys
import re

# --- 配置区 ---

# C语言源文件所在的目录 (单个文件模式下，这个目录可能不再需要，但保留以保持路径结构一致)
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

def run_single_test(c_file_path: str) -> bool:
    """
    对单个测试用例执行完整的编译、运行和验证流程。
    c_file_path: 完整的C源文件路径，例如 'ctest/fib.c'
    返回 True 表示测试通过，False 表示失败。
    """
    # 从路径中提取基础名称 (例如 'ctest/fib.c' -> 'fib')
    base_name = os.path.splitext(os.path.basename(c_file_path))[0]
    
    # 确保传入的文件名以 .c 结尾
    if not c_file_path.lower().endswith('.c'):
        print(f"{Style.RED}{Style.FAILED} Error: Input file '{c_file_path}' must be a '.c' file.{Style.RESET}")
        return False
        
    print(f"\n{Style.BLUE}===== Running Test for: {base_name} ({c_file_path}) [{TARGET_ARCH}] ====={Style.RESET}")

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
            print(f"{Style.RED}{Style.FAILED} Error: Compilation to {TARGET_ARCH} assembly failed for '{c_file_path}'.{Style.RESET}")
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
        # 添加 -lm 以确保浮点数学库也被链接（如果需要）
        cmd_clang_std = ["clang", "-o", std_executable, c_file_path, RUNTIME_C, "-lm"]
        result = subprocess.run(cmd_clang_std, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"{Style.RED}{Style.FAILED} Error: Clang failed to compile the source file '{c_file_path}'.{Style.RESET}")
            if result.stdout or result.stderr:
                print(f"{Style.YELLOW}{Style.ARROW} Clang output:{Style.RESET}\n{result.stdout}{result.stderr}")
            return False

        # 5. 运行两个可执行文件并比较结果
        print(f"{Style.RUN} Executing both versions...")
        # 核心修改点C：直接运行目标可执行文件 (不需要模拟器)
        moon_result = subprocess.run([f"./{moon_executable}"], capture_output=True, text=True)
        std_result = subprocess.run([f"./{std_executable}"], capture_output=True, text=True)

        # 正常情况下，我们直接比较 subprocess.run 报告的退出码
        ret_ok = moon_result.returncode == std_result.returncode
        stdout_ok = moon_result.stdout == std_result.stdout
        stderr_ok = moon_result.stderr == std_result.stderr

        if ret_ok and stdout_ok and stderr_ok:
            print(f"{Style.GREEN}{Style.PASSED} Test '{c_file_path}' PASSED! Outputs match perfectly.{Style.RESET}")
            return True
        else:
            print(f"{Style.RED}{Style.FAILED} Test '{c_file_path}' FAILED! Outputs do not match.{Style.RESET}")
            if not ret_ok:
                print(f"{Style.YELLOW} - Return codes differ: [moon: {moon_result.returncode}] vs [std: {std_result.returncode}]{Style.RESET}")
            if not stdout_ok:
                print(f"{Style.YELLOW} - Standard outputs differ.{Style.RESET}")
                print(f"{Style.CYAN}--- Moon stdout ---\n{moon_result.stdout.strip()}{Style.RESET}")
                print(f"{Style.CYAN}--- Standard stdout ---\n{std_result.stdout.strip()}{Style.RESET}")
            if not stderr_ok:
                print(f"{Style.YELLOW} - Standard errors differ.{Style.RESET}")
                print(f"{Style.CYAN}--- Moon stderr ---\n{moon_result.stderr.strip()}{Style.RESET}")
                print(f"{Style.CYAN}--- Standard stderr ---\n{std_result.stderr.strip()}{Style.RESET}")
            
            return False

    finally:
        # 6. 清理生成的所有文件
        print(f"\n{Style.CLEAN} Cleaning up generated files for '{base_name}'...")
        files_to_remove = [s_file, moon_executable, std_executable]
        for f in files_to_remove:
            if os.path.exists(f):
                try:
                    os.remove(f)
                    print(f"  Removed: {f}")
                except OSError as e:
                    print(f"{Style.RED}{Style.WARN} Warning: Could not remove file '{f}': {e}{Style.RESET}")


def main():
    """脚本主入口，接收单个C文件参数并运行测试"""
    print(f"{Style.GREEN}Starting the single-file {TARGET_ARCH} test...{Style.RESET}")

    # 检查运行时文件
    if not os.path.exists(RUNTIME_C):
        print(f"{Style.RED}{Style.FAILED} Critical Error: '{RUNTIME_C}' not found. Aborting tests.{Style.RESET}")
        sys.exit(1)

    # 检查当前系统是否支持直接运行 aarch64 可执行文件
    if os.uname().machine not in ['aarch64', 'arm64']:
         print(f"{Style.WARN}{Style.YELLOW}Warning: Current machine architecture is not native {TARGET_ARCH} ({os.uname().machine}). Direct execution might fail unless QEMU or similar emulation is set up.{Style.RESET}")

    # 检查参数数量
    if len(sys.argv) != 2:
        print(f"{Style.RED}{Style.FAILED} Usage: {sys.argv[0]} <path/to/source.c>{Style.RESET}")
        print(f"{Style.INFO} Example: ./{sys.argv[0]} fib.c (assuming fib.c is in the current directory, or ctest/fib.c if it's in ctest/){Style.RESET}")
        sys.exit(1)

    input_file = sys.argv[1]
    
    # 尝试构建路径：如果输入的文件名不包含路径，则默认尝试 C_SOURCE_DIR 目录
    # 否则使用完整的输入路径
    if not os.path.isabs(input_file) and not os.path.dirname(input_file):
        c_file_path = os.path.join(C_SOURCE_DIR, input_file)
    else:
        c_file_path = input_file
        
    # 如果默认路径不存在，则回退到用户输入的路径（可能是当前目录）
    if not os.path.exists(c_file_path):
        c_file_path = input_file
        
    if run_single_test(c_file_path):
        print(f"\n{Style.SUMMARY}{Style.GREEN}{Style.CELEBRATE} All checks PASSED for {input_file} ({TARGET_ARCH})!{Style.RESET}")
        sys.exit(0)
    else:
        print(f"\n{Style.SUMMARY}{Style.RED}{Style.FAILED} Test FAILED for {input_file} ({TARGET_ARCH}).{Style.RESET}")
        sys.exit(1)


if __name__ == "__main__":
    main()
