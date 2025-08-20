#!/bin/bash

# 编译环境检查和安装脚本
# 支持 Linux 和 macOS
# 检查和安装必要的编译工具链

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查结果统计
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=()
WARNINGS=()

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 询问用户是否安装
ask_install() {
    local tool_name="$1"
    local install_cmd="$2"
    
    echo ""
    read -p "是否要安装 $tool_name? [y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "正在安装 $tool_name..."
        eval "$install_cmd"
        return $?
    else
        print_warning "跳过安装 $tool_name"
        return 1
    fi
}

# 检查命令是否存在
check_command() {
    local cmd="$1"
    local name="$2"
    local install_cmd="$3"
    local required="$4"  # true/false
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if command -v "$cmd" &> /dev/null; then
        local version=""
        case "$cmd" in
            "meson")
                version=$(meson --version 2>/dev/null || echo "未知版本")
                ;;
            "ninja")
                version=$(ninja --version 2>/dev/null || echo "未知版本")
                ;;
            "gcc")
                version=$(gcc --version 2>/dev/null | head -n1 | awk '{print $4}' || echo "未知版本")
                ;;
            *)
                version=$($cmd --version 2>/dev/null | head -n1 || echo "已安装")
                ;;
        esac
        print_success "$name 已安装: $version"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        if [[ "$required" == "true" ]]; then
            print_error "$name 未找到"
            FAILED_CHECKS+=("$name")
            
            if [[ -n "$install_cmd" ]]; then
                if ask_install "$name" "$install_cmd"; then
                    print_success "$name 安装完成"
                    PASSED_CHECKS=$((PASSED_CHECKS + 1))
                    return 0
                fi
            fi
        else
            print_warning "$name 未找到 (可选)"
            WARNINGS+=("$name")
        fi
        return 1
    fi
}

# 检查包是否安装（仅限 Linux）
check_package() {
    local package="$1"
    local name="$2"
    local install_cmd="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # 检查不同的包管理器
    if command -v dpkg &> /dev/null; then
        # Debian/Ubuntu
        if dpkg -l | grep -q "^ii  $package "; then
            print_success "$name 已安装"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        fi
    elif command -v rpm &> /dev/null; then
        # Red Hat/CentOS/Fedora
        if rpm -q "$package" &> /dev/null; then
            print_success "$name 已安装"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        fi
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        if pacman -Q "$package" &> /dev/null; then
            print_success "$name 已安装"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        fi
    fi
    
    print_error "$name 未安装"
    FAILED_CHECKS+=("$name")
    
    if ask_install "$name" "$install_cmd"; then
        print_success "$name 安装完成"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    fi
    
    return 1
}

# 检查环境变量
check_env_var() {
    local var_name="$1"
    local var_description="$2"
    local default_path="$3"
    local required="$4"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ -n "${!var_name}" ]]; then
        local var_value="${!var_name}"
        if [[ -d "$var_value" ]]; then
            print_success "$var_description 已设置: $var_value"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        else
            print_error "$var_description 路径不存在: $var_value"
        fi
    else
        print_error "$var_description 未设置"
    fi
    
    FAILED_CHECKS+=("$var_description")
    
    if [[ -n "$default_path" && -d "$default_path" ]]; then
        echo ""
        read -p "是否设置 $var_name 为默认路径 $default_path? [y/N]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 添加到 ~/.bashrc 和 ~/.profile
            echo "export $var_name=\"$default_path\"" >> ~/.bashrc
            if [[ -f ~/.profile ]]; then
                echo "export $var_name=\"$default_path\"" >> ~/.profile
            fi
            export "$var_name"="$default_path"
            print_success "$var_description 已设置为: $default_path"
            print_info "请重新加载 shell 或执行: source ~/.bashrc"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        fi
    fi
    
    return 1
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# 检测Ubuntu版本
get_ubuntu_version() {
    if [[ -f /etc/lsb-release ]]; then
        source /etc/lsb-release
        echo "$DISTRIB_RELEASE"
    elif command -v lsb_release &> /dev/null; then
        lsb_release -rs
    else
        echo "unknown"
    fi
}

# 检查Ubuntu版本是否支持ARM64 MinGW（实际上当前版本都不支持）
ubuntu_supports_arm64_mingw() {
    local version="$1"
    # 实际测试表明，即使Ubuntu 24.04+ 也不提供 ARM64 MinGW工具链
    # 保留此函数以备将来版本可能支持
    if [[ "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        local major=$(echo "$version" | cut -d. -f1)
        local minor=$(echo "$version" | cut -d. -f2)
        # 目前没有版本原生支持，返回false
        if [[ $major -gt 25 ]]; then  # 假设未来26.04+可能支持
            return 0
        fi
    fi
    return 1
}

# 检查包是否在仓库中可用
check_package_available() {
    local package="$1"
    apt-cache search "^${package}$" &>/dev/null && apt-cache show "$package" &>/dev/null
}

# 提供ARM64 MinGW的替代安装方案
suggest_arm64_mingw_alternatives() {
    print_warning "检测到Ubuntu $(get_ubuntu_version)，官方仓库不包含ARM64 MinGW工具链"
    echo ""
    print_info "ARM64 MinGW工具链替代方案："
    echo "1. 使用Docker容器构建 (推荐)"
    echo "2. 在Windows环境下使用Visual Studio或WDK"
    echo "3. 使用GitHub Actions等CI/CD服务"
    echo "4. 手动编译mingw-w64工具链"
    echo ""
    
    read -p "是否查看详细的替代方案说明? [y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        print_info "详细方案："
        echo ""
        echo "🐳 Docker方案 (推荐):"
        echo "   # 从项目根目录运行（挂载整个项目）"
        echo "   cd .. && docker run --rm -v \$(pwd):/workspace dockcross/windows-arm64 bash -c \\"
        echo "     \\\"cd /workspace/MesonBuild && ./scripts/build-platform.sh windows-arm64\\\""
        echo ""
        echo "   # 或创建自定义Dockerfile:"
        echo "   # FROM ubuntu:24.04"
        echo "   # RUN apt update && apt install -y build-essential meson ninja-build"
        echo "   # RUN apt install -y gcc-aarch64-w64-mingw32 || echo 'ARM64 MinGW not available'"
        echo ""
        echo "🏗️ CI/CD方案:"
        echo "   在GitHub Actions中使用ubuntu-23.10或更新版本"
        echo "   或使用专门的交叉编译Docker镜像"
        echo ""
        echo "🔧 手动编译 (高级用户):"
        echo "   从源码编译mingw-w64工具链，添加ARM64支持"
        echo ""
        return 0
    fi
    return 1
}

# 检查 Android NDK
check_android_ndk() {
    print_info "检查 Android NDK..."
    
    # 检查 ANDROID_NDK_ROOT 环境变量
    local default_ndk_paths=(
        "$HOME/Android/Sdk/ndk-bundle"
        "$HOME/android-ndk"
        "/opt/android-ndk"
        "/usr/local/android-ndk"
    )
    
    local found_ndk=""
    for path in "${default_ndk_paths[@]}"; do
        if [[ -d "$path" ]]; then
            found_ndk="$path"
            break
        fi
    done
    
    check_env_var "ANDROID_NDK_ROOT" "Android NDK" "$found_ndk" true
    
    # 检查 NDK 工具链
    if [[ -n "$ANDROID_NDK_ROOT" && -d "$ANDROID_NDK_ROOT" ]]; then
        local toolchain_dir="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
        if [[ "$OS" == "macos" ]]; then
            toolchain_dir="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64/bin"
        fi
        
        if [[ -d "$toolchain_dir" ]]; then
            print_success "Android NDK 工具链找到: $toolchain_dir"
        else
            print_error "Android NDK 工具链目录不存在: $toolchain_dir"
        fi
    fi
}

# 主函数
main() {
    echo "========================================"
    echo "Unity SQLCipher 编译环境检查"
    echo "========================================"
    echo ""
    
    # 检测操作系统
    OS=$(detect_os)
    print_info "检测到操作系统: $OS"
    echo ""
    
    # 检查基础构建工具
    print_info "检查基础构建工具..."
    check_command "meson" "Meson 构建系统" "pip3 install meson" true
    
    # 根据操作系统设置 ninja 安装命令
    if [[ "$OS" == "macos" ]]; then
        check_command "ninja" "Ninja 构建工具" "brew install ninja" true
    else
        check_command "ninja" "Ninja 构建工具" "sudo apt-get install -y ninja-build" true
    fi
    
    # 根据操作系统检查特定工具
    if [[ "$OS" == "linux" ]]; then
        print_info "检查 Linux 构建环境..."
        
        # 检查 build-essential
        check_package "build-essential" "构建基础工具" "sudo apt-get update && sudo apt-get install -y build-essential"
        
        # 检查 MinGW 交叉编译工具链
        print_info "检查 Windows 交叉编译工具链..."
        check_command "i686-w64-mingw32-gcc" "MinGW 32位交叉编译器 (windows-x86)" "sudo apt-get install -y gcc-mingw-w64-i686" false
        check_command "x86_64-w64-mingw32-gcc" "MinGW 64位交叉编译器 (windows-x86_64)" "sudo apt-get install -y gcc-mingw-w64-x86-64" false
        
        # 检查 ARM64 交叉编译器
        print_info "检查 ARM64 MinGW 交叉编译器..."
        if command -v aarch64-w64-mingw32-gcc &> /dev/null; then
            print_success "MinGW ARM64交叉编译器 (windows-arm64) 已安装"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            print_warning "MinGW ARM64交叉编译器 (windows-arm64) 未找到"
            
            # 检查是否可以通过临时仓库安装
            ubuntu_version=$(get_ubuntu_version)
            print_info "检测到 Ubuntu $ubuntu_version"
            
            # 首先检查当前仓库是否有该包
            if check_package_available "gcc-aarch64-w64-mingw32"; then
                print_info "当前仓库支持直接安装"
                if ask_install "ARM64 MinGW工具链" "sudo apt-get install -y gcc-aarch64-w64-mingw32"; then
                    print_success "ARM64 MinGW工具链安装完成"
                    PASSED_CHECKS=$((PASSED_CHECKS + 1))
                else
                    WARNINGS+=("MinGW ARM64交叉编译器")
                fi
            else
                print_info "当前仓库不包含ARM64 MinGW工具链"
                suggest_arm64_mingw_alternatives
                WARNINGS+=("MinGW ARM64交叉编译器")
            fi
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        
    elif [[ "$OS" == "macos" ]]; then
        print_info "检查 macOS 构建环境..."
        
        # 检查完整的 Xcode 安装
        print_info "检查 Xcode 环境..."
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
            FAILED_CHECKS+=("Xcode 命令行工具")
            if ask_install "Xcode 命令行工具" "xcode-select --install"; then
                print_success "Xcode 命令行工具安装完成"
                print_info "请重启终端或执行: source ~/.bashrc"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            fi
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        
        # 检查 Homebrew
        print_info "检查包管理器..."
        if command -v brew &> /dev/null; then
            brew_version=$(brew --version 2>/dev/null | head -n1 || echo "未知版本")
            print_success "Homebrew 已安装: $brew_version"
            
            # 检查 Homebrew 环境变量
            if [[ ":$PATH:" != *":/opt/homebrew/bin:"* ]] && [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
                print_warning "Homebrew 可能未正确添加到 PATH"
                echo ""
                read -p "是否自动添加 Homebrew 到环境变量? [y/N]: " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    # 检测 Apple Silicon 或 Intel Mac
                    if [[ $(uname -m) == "arm64" ]]; then
                        echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.bashrc
                        echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc 2>/dev/null || true
                        print_success "已添加 Homebrew (Apple Silicon) 到环境变量"
                    else
                        echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
                        echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc 2>/dev/null || true
                        print_success "已添加 Homebrew (Intel) 到环境变量"
                    fi
                    print_info "请重启终端或执行: source ~/.bashrc"
                fi
            fi
        else
            print_warning "Homebrew 未安装，建议安装以便管理依赖"
            if ask_install "Homebrew" '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; then
                print_success "Homebrew 安装完成"
                print_info "请重启终端或执行 Homebrew 的环境设置命令"
            fi
        fi
        
        # 检查 ninja (macOS)
        if ! command -v ninja &> /dev/null; then
            check_command "ninja" "Ninja 构建工具" "brew install ninja" true
        fi
        
        # 检查 MinGW 交叉编译工具链 (macOS)
        print_info "检查 Windows 交叉编译工具链..."
        
        # 在macOS上，mingw-w64通过Homebrew安装，包含所有架构
        if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
            print_success "MinGW-w64 工具链已安装"
            
            # 检查各个架构
            if command -v i686-w64-mingw32-gcc &> /dev/null; then
                print_success "MinGW 32位交叉编译器 (windows-x86) 可用"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            fi
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            
            if command -v x86_64-w64-mingw32-gcc &> /dev/null; then
                print_success "MinGW 64位交叉编译器 (windows-x86_64) 可用"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            fi
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            
            # macOS上检查ARM64 MinGW（较新版本的mingw-w64可能包含）
            if command -v aarch64-w64-mingw32-gcc &> /dev/null; then
                print_success "MinGW ARM64交叉编译器 (windows-arm64) 可用"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                print_warning "MinGW ARM64交叉编译器 (windows-arm64) 不可用"
                print_info "当前Homebrew的mingw-w64可能不包含ARM64支持"
                WARNINGS+=("MinGW ARM64交叉编译器")
            fi
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            
        else
            print_warning "MinGW-w64 工具链未安装"
            if ask_install "MinGW-w64 完整工具链" "brew install mingw-w64"; then
                print_success "MinGW-w64 工具链安装完成"
                print_info "现在支持 windows-x86 和 windows-x86_64 目标"
                
                # 重新检查ARM64支持
                if command -v aarch64-w64-mingw32-gcc &> /dev/null; then
                    print_success "同时获得了 ARM64 支持 (windows-arm64)"
                else
                    print_info "当前版本不包含 ARM64 支持"
                fi
                
                PASSED_CHECKS=$((PASSED_CHECKS + 3))  # x86, x86_64, 可能的ARM64
            else
                FAILED_CHECKS+=("MinGW-w64 工具链")
            fi
            TOTAL_CHECKS=$((TOTAL_CHECKS + 3))
        fi
    fi
    
    echo ""
    
    # 检查 Android NDK
    check_android_ndk
    
    echo ""
    
    # 输出检查结果
    echo "========================================"
    echo "环境检查结果汇总:"
    echo "========================================"
    print_info "总检查项目: $TOTAL_CHECKS"
    print_success "通过检查: $PASSED_CHECKS"
    
    if [[ ${#FAILED_CHECKS[@]} -gt 0 ]]; then
        print_error "失败检查: ${#FAILED_CHECKS[@]}"
        echo "失败项目:"
        for item in "${FAILED_CHECKS[@]}"; do
            echo "  - $item"
        done
    fi
    
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        print_warning "警告项目: ${#WARNINGS[@]}"
        echo "警告项目:"
        for item in "${WARNINGS[@]}"; do
            echo "  - $item"
        done
    fi
    
    echo ""
    
    if [[ ${#FAILED_CHECKS[@]} -eq 0 ]]; then
        print_success "所有必需的工具都已安装，环境检查通过！"
        echo ""
        print_info "你现在可以运行构建脚本:"
        echo "  ./build-all.sh"
        echo "  ./build-platform.sh <platform> [debug|release]"
        exit 0
    else
        print_error "环境检查未完全通过，请安装缺失的工具"
        echo ""
        print_info "安装指南:"
        
        if [[ "$OS" == "linux" ]]; then
            echo ""
            echo "Ubuntu/Debian 系统快速安装命令:"
            echo "  sudo apt-get update"
            echo "  sudo apt-get install -y build-essential meson ninja-build"
            echo "  sudo apt-get install -y gcc-mingw-w64-i686 gcc-mingw-w64-x86-64"
            echo "  pip3 install meson"
            echo ""
            echo ""
            echo "Android NDK 下载:"
            echo "  https://developer.android.com/ndk/downloads"
            echo "  解压后设置 ANDROID_NDK_ROOT 环境变量"
            echo ""
            echo "ARM64 MinGW (windows-arm64):"
            echo "  当前Ubuntu版本不支持，可使用Docker或CI/CD方案"
            echo "  运行 './check-env.sh' 查看详细替代方案"
            
        elif [[ "$OS" == "macos" ]]; then
            echo ""
            echo "macOS 系统快速安装命令:"
            echo "  xcode-select --install"
            echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            echo "  brew install meson ninja mingw-w64"
            echo ""
            echo "Android NDK 下载:"
            echo "  https://developer.android.com/ndk/downloads"
            echo "  解压后设置 ANDROID_NDK_ROOT 环境变量"
            echo ""
            echo "ARM64 MinGW (windows-arm64):"
            echo "  检查最新版mingw-w64是否包含ARM64支持"
        fi
        
        exit 1
    fi
}

# 脚本入口
main "$@"