#!/bin/bash

# macOS平台检查模块
# 检查macOS特定的构建环境：Xcode, Homebrew

# 导入公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

# 检查Xcode环境
check_xcode() {
    print_info "检查 Xcode 环境..."
    
    # 检查完整的 Xcode 安装
    if command -v xcodebuild &> /dev/null; then
        xcode_version=$(xcodebuild -version 2>/dev/null | head -n1 || echo "未知版本")
        print_success "Xcode 已安装: $xcode_version"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_warning "Xcode 未安装，仅检测到命令行工具"
        print_info "对于完整的开发环境，建议从 App Store 安装 Xcode"
        WARNINGS+=("完整 Xcode")
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # 检查 Xcode 命令行工具
    if xcode-select -p &> /dev/null; then
        xcode_path=$(xcode-select -p)
        print_success "Xcode 命令行工具已安装: $xcode_path"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_error "Xcode 命令行工具未安装"
        
        if [[ "$AUTO_ACCEPT" == "true" ]]; then
            print_info "自动安装模式: 安装 Xcode 命令行工具..."
            if xcode-select --install 2>/dev/null; then
                print_success "Xcode 命令行工具安装完成"
                print_info "请重启终端或执行: source ~/.bashrc"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                FAILED_CHECKS+=("Xcode 命令行工具")
            fi
        elif ask_install "Xcode 命令行工具" "xcode-select --install"; then
            print_success "Xcode 命令行工具安装完成"
            print_info "请重启终端或执行: source ~/.bashrc"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            FAILED_CHECKS+=("Xcode 命令行工具")
        fi
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

# 检查Homebrew环境
check_homebrew() {
    print_info "检查包管理器..."
    
    if command -v brew &> /dev/null; then
        brew_version=$(brew --version 2>/dev/null | head -n1 || echo "未知版本")
        print_success "Homebrew 已安装: $brew_version"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_warning "Homebrew 未安装，建议安装以便管理依赖"
        
        if [[ "$AUTO_ACCEPT" == "true" ]]; then
            print_info "自动安装模式: 安装 Homebrew..."
            if /bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)" 2>/dev/null; then
                print_success "Homebrew 安装完成"
                print_info "请重启终端或执行 Homebrew 的环境设置命令"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                FAILED_CHECKS+=("Homebrew")
            fi
        elif ask_install "Homebrew" '/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"'; then
            print_success "Homebrew 安装完成"
            print_info "请重启终端或执行 Homebrew 的环境设置命令"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            FAILED_CHECKS+=("Homebrew")
        fi
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

# 检查macOS特定环境
check_macos_specific() {
    print_info "检查 macOS 特定构建环境..."
    check_xcode
    check_homebrew
}

# 检查iOS特定环境
check_ios_specific() {
    print_info "检查 iOS 特定构建环境..."
    check_xcode
}
