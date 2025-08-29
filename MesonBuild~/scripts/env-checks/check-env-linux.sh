#!/bin/bash

# Linux平台检查模块
# 检查Linux特定的构建环境：build-essential, MinGW交叉编译工具

# 导入公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

# 检查Linux特定环境
check_linux_specific() {
    print_info "检查 Linux 特定构建环境..."
    check_package "build-essential" "构建基础工具" "sudo apt-get update && sudo apt-get install -y build-essential"
}

# 检查Windows交叉编译环境
check_windows_specific() {
    print_info "检查 Windows 交叉编译工具链..."

    if [[ "$OS" == "linux" ]]; then
        check_command "i686-w64-mingw32-gcc" "MinGW 32位交叉编译器 (windows-x86)" "sudo apt-get install -y gcc-mingw-w64-i686" false
        check_command "x86_64-w64-mingw32-gcc" "MinGW 64位交叉编译器 (windows-x86_64)" "sudo apt-get install -y gcc-mingw-w64-x86-64" false
        
        # 检查ARM64 MinGW（较新版本可能支持）
        if command -v aarch64-w64-mingw32-gcc &> /dev/null; then
            print_success "MinGW ARM64交叉编译器 (windows-arm64) 可用"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            print_warning "MinGW ARM64交叉编译器 (windows-arm64) 不可用"
            print_info "当前Ubuntu版本可能不包含ARM64支持"
            WARNINGS+=("MinGW ARM64交叉编译器")
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        
    elif [[ "$OS" == "macos" ]]; then
        if [[ "$AUTO_ACCEPT" == "true" ]]; then
            print_info "自动安装模式: 安装 MinGW-w64 工具链..."
            if brew install mingw-w64 2>/dev/null; then
                print_success "MinGW-w64 工具链安装完成"
                print_info "现在支持 windows-x86 和 windows-x86_64 目标"
                print_info "当前版本不包含 ARM64 支持"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                FAILED_CHECKS+=("MinGW-w64 工具链")
            fi
        elif ask_install "MinGW-w64 完整工具链" "brew install mingw-w64"; then
            print_success "MinGW-w64 工具链安装完成"
            print_info "现在支持 windows-x86 和 windows-x86_64 目标"
            print_info "当前版本不包含 ARM64 支持"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            FAILED_CHECKS+=("MinGW-w64 工具链")
        fi
    fi
}
