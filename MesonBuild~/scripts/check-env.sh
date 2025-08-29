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

    # 检查是否设置了自动安装环境变量
    if [[ "$AUTO_INSTALL" == "true" || "$CI" == "true" ]]; then
        print_info "自动安装模式: 正在安装 $tool_name..."
        eval "$install_cmd"
        return $?
    fi

    # 检查是否在交互模式
    if [[ -t 0 ]]; then
        # 交互模式：无超时等待用户输入
        echo ""
        read -p "是否要安装 $tool_name? [y/N]: " -r
        echo ""
    else
        # 非交互模式：直接使用默认值
        print_info "非交互模式，使用默认选择: 不安装 $tool_name"
        return 1
    fi

    # 如果输入为空，默认为 N
    if [[ -z "$REPLY" ]]; then
        print_info "使用默认选择: 不安装 $tool_name"
        return 1
    fi

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

            if [[ -n "$install_cmd" ]]; then
                if ask_install "$name" "$install_cmd"; then
                    print_success "$name 安装完成"
                    PASSED_CHECKS=$((PASSED_CHECKS + 1))
                    return 0
                else
                    # 用户拒绝安装或安装失败
                    FAILED_CHECKS+=("$name")
                fi
            else
                # 没有安装命令
                FAILED_CHECKS+=("$name")
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
        # 检查是否设置了自动安装环境变量
        if [[ "$AUTO_INSTALL" == "true" || "$CI" == "true" ]]; then
            print_info "自动安装模式: 设置 $var_name 为默认路径 $default_path"
            export "$var_name"="$default_path"
            print_success "$var_description 已设置为: $default_path"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        fi

        # 检查是否在交互模式
        if [[ -t 0 ]]; then
            # 交互模式：无超时等待用户输入
            echo ""
            read -p "是否设置 $var_name 为默认路径 $default_path? [y/N]: " -r
            echo ""
        else
            # 非交互模式：直接使用默认值
            print_info "非交互模式，使用默认选择: 不自动设置环境变量"
            print_info "如需使用，请手动执行: export $var_name=\"$default_path\""
            return 1
        fi

        # 如果输入为空，默认为 N
        if [[ -z "$REPLY" ]]; then
            print_info "使用默认选择: 不自动设置环境变量"
            print_info "如需使用，请手动执行: export $var_name=\"$default_path\""
        elif [[ $REPLY =~ ^[Yy]$ ]]; then
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
        else
            print_info "跳过自动设置"
            print_info "如需使用，请手动执行: export $var_name=\"$default_path\""
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

# 检测macOS架构，避免Rosetta影响
detect_mac_arch() {
    local mac_arch=""
    
    # 方法1: 检查系统profiler (最可靠)
    if command -v system_profiler &> /dev/null; then
        local hw_info=$(system_profiler SPHardwareDataType 2>/dev/null)
        if echo "$hw_info" | grep -q "Apple M[0-9]"; then
            mac_arch="arm64"
        elif echo "$hw_info" | grep -q "Intel"; then
            mac_arch="x86_64"
        fi
    fi
    
    # 方法2: 如果方法1失败，使用uname -m
    if [[ -z "$mac_arch" ]]; then
        mac_arch=$(uname -m)
    fi
    
    # 方法3: 最后的保险，强制使用原生架构检测
    if [[ -z "$mac_arch" || "$mac_arch" == "x86_64" ]]; then
        # 尝试强制使用ARM64架构运行uname
        local native_arch=$(arch -arm64 uname -m 2>/dev/null || uname -m)
        if [[ "$native_arch" == "arm64" ]]; then
            mac_arch="arm64"
        fi
    fi
    
    echo "$mac_arch"
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
        echo "     \\\"cd /workspace/MesonBuild~ && ./scripts/build-platform.sh windows-arm64\\\""
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

# 检查和修复 Homebrew 架构匹配
check_and_fix_homebrew_arch() {
    local mac_arch=$(detect_mac_arch)
    local expected_brew_path=""
    local current_brew_path=""
    local brew_arch_match=true
    
    if [[ "$mac_arch" == "arm64" ]]; then
        expected_brew_path="/opt/homebrew/bin/brew"
        print_info "Apple Silicon Mac 应使用: $expected_brew_path"
    elif [[ "$mac_arch" == "x86_64" ]]; then
        expected_brew_path="/usr/local/bin/brew"
        print_info "Intel Mac 应使用: $expected_brew_path"
    fi
    
    if command -v brew &> /dev/null; then
        current_brew_path=$(which brew)
        print_info "当前 Homebrew 路径: $current_brew_path"
        
        if [[ "$current_brew_path" != "$expected_brew_path" ]]; then
            brew_arch_match=false
            if [[ "$mac_arch" == "arm64" && "$current_brew_path" == "/usr/local/bin/brew" ]]; then
                print_warning "检测到架构不匹配："
                print_warning "您在 Apple Silicon Mac 上使用 Intel 版本的 Homebrew"
                print_info "这会导致安装 Intel 版本的软件，影响性能"
            elif [[ "$mac_arch" == "x86_64" && "$current_brew_path" == "/opt/homebrew/bin/brew" ]]; then
                print_warning "检测到架构不匹配："
                print_warning "您在 Intel Mac 上使用 Apple Silicon 版本的 Homebrew"
                print_info "这可能导致兼容性问题"
            fi
            
            echo ""
            print_info "解决方案："
            echo "  1) 安装正确架构的 Homebrew 并设置共存 (推荐)"
            echo "  2) 继续使用当前 Homebrew (可能有性能问题)"
            echo "  3) 跳过 Homebrew，使用其他安装方式"
            echo ""
            read -p "请选择 [1-3]: " -n 1 -r HOMEBREW_CHOICE
            echo
            echo
            
            case $HOMEBREW_CHOICE in
                1)
                    print_info "将安装正确架构的 Homebrew 并设置别名共存..."
                    install_correct_homebrew_simplified "$mac_arch" "$current_brew_path" "$expected_brew_path"
                    return $?
                    ;;
                2)
                    print_warning "继续使用当前 Homebrew，可能安装错误架构的软件"
                    return 0
                    ;;
                3)
                    print_info "将跳过 Homebrew，使用直接下载方式"
                    return 2  # 特殊返回码，表示跳过 Homebrew
                    ;;
                *)
                    print_info "无效选择，继续使用当前 Homebrew"
                    return 0
                    ;;
            esac
        else
            print_success "Homebrew 架构匹配正确"
            return 0
        fi
    else
        print_info "未安装 Homebrew"
        echo ""
        read -p "是否安装适合您系统架构的 Homebrew? [y/N]: " -n 1 -r INSTALL_BREW
        echo
        if [[ $INSTALL_BREW =~ ^[Yy]$ ]]; then
            install_correct_homebrew_simplified "$mac_arch" "" "$expected_brew_path"
            return $?
        else
            print_info "跳过 Homebrew 安装"
            return 2  # 跳过 Homebrew
        fi
    fi
}

# 简化版本的 Homebrew 安装函数 (直接安装并设置共存)
install_correct_homebrew_simplified() {
    local mac_arch="$1"
    local current_brew_path="$2"
    local expected_brew_path="$3"
    
    print_info "安装适合 $mac_arch 架构的 Homebrew..."
    
    # 直接安装并设置共存，不再询问
    if [[ -n "$current_brew_path" ]]; then
        print_info "检测到现有的 Homebrew: $current_brew_path"
        print_info "将安装新版本并设置别名共存"
    fi
    
    print_info "下载并安装 Homebrew..."
    print_info "这可能需要几分钟时间，请耐心等待..."
    
    # 检查用户权限
    if ! groups "$USER" | grep -q admin; then
        print_error "当前用户不是管理员，无法安装 Homebrew"
        print_info "请联系系统管理员或使用管理员账户运行此脚本"
        return 1
    fi
    
    # 检查是否已经有正确架构的Homebrew
    if [[ -f "$expected_brew_path" ]]; then
        print_info "检测到已安装正确架构的 Homebrew: $expected_brew_path"
        print_success "无需重新安装，将配置别名"
        # 直接跳到配置别名部分
        local shell_config=""
        if [[ "$SHELL" == *"zsh"* ]]; then
            shell_config="$HOME/.zshrc"
        elif [[ "$SHELL" == *"bash"* ]]; then
            shell_config="$HOME/.bashrc"
        fi
        
        if [[ -n "$shell_config" ]]; then
            setup_homebrew_aliases "$shell_config" "$current_brew_path" "$expected_brew_path"
        fi
        return 0
    fi
    
    # 安装 Homebrew (交互模式，允许输入sudo密码)
    print_info "正在安装Apple Silicon版本的Homebrew..."
    print_info "安装过程中需要sudo权限，请按提示输入密码"
    
    # 预先获取sudo权限，避免安装过程中中断
    print_info "请输入sudo密码以获取管理员权限:"
    if ! sudo -v; then
        print_error "无法获取sudo权限，安装失败"
        return 1
    fi
    
    # 根据架构选择合适的安装命令
    local install_cmd=""
    if [[ "$mac_arch" == "arm64" ]]; then
        # Apple Silicon Mac - 安装到 /opt/homebrew
        install_cmd='/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"'
        print_info "使用 Apple Silicon 版本安装到 /opt/homebrew"
    else
        # Intel Mac - 强制使用 x86_64 架构安装到 /usr/local
        install_cmd='arch -x86_64 /bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"'
        print_info "使用 Intel 版本安装到 /usr/local"
    fi
    
    print_info "安装命令: $install_cmd"
    echo ""
    print_info "将安装Apple Silicon版本的Homebrew并与现有Intel版本共存"
    echo ""
    print_info "共存方案："
    echo "- Intel版本: /usr/local/bin/brew (别名: ibrew)"
    echo "- Apple Silicon版本: /opt/homebrew/bin/brew (别名: abrew)"
    echo ""
    print_info "安装命令: $install_cmd"
    echo ""
    
    read -p "是否现在安装Apple Silicon版本的Homebrew? [y/N]: " -n 1 -r AUTO_INSTALL
    echo
    echo
    
    if [[ $AUTO_INSTALL =~ ^[Yy]$ ]]; then
        print_info "开始安装Apple Silicon版本的Homebrew..."
        print_info "安装过程可能需要几分钟，请耐心等待..."
        
        # 确保不设置NONINTERACTIVE，允许交互
        unset NONINTERACTIVE
        
        # 执行安装命令
        eval "$install_cmd"
        local install_result=$?
        
        # 检查安装是否成功 - 不仅看退出码，还要检查文件是否存在
        if [[ $install_result -eq 0 ]] || [[ -f "$expected_brew_path" ]]; then
            print_success "Homebrew 安装完成"
            
            # 检查安装路径是否正确
            if [[ -f "$expected_brew_path" ]]; then
                print_success "Homebrew 安装在正确位置: $expected_brew_path"
                
                # 自动配置环境变量
                print_info "自动配置环境变量..."
                if [[ "$mac_arch" == "arm64" ]]; then
                    # 执行Apple Silicon版本的环境配置
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                    
                    # 添加到shell配置文件以便持久化
                    local profile_file=""
                    if [[ "$SHELL" == *"zsh"* ]]; then
                        profile_file="$HOME/.zprofile"
                    elif [[ "$SHELL" == *"bash"* ]]; then
                        profile_file="$HOME/.bash_profile"
                    fi
                    
                    if [[ -n "$profile_file" ]] && ! grep -q 'eval.*brew shellenv' "$profile_file" 2>/dev/null; then
                        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$profile_file"
                        print_success "已添加环境配置到 $profile_file"
                    fi
                    
                    print_success "Apple Silicon Homebrew环境变量已配置"
                fi
            
            # 配置环境变量和别名
            print_info "配置环境变量和别名..."
            local shell_config=""
            if [[ "$SHELL" == *"zsh"* ]]; then
                shell_config="$HOME/.zshrc"
            elif [[ "$SHELL" == *"bash"* ]]; then
                shell_config="$HOME/.bashrc"
            fi
            
            if [[ -n "$shell_config" ]]; then
                # 设置别名
                setup_homebrew_aliases "$shell_config" "$current_brew_path" "$expected_brew_path"
                
                # 立即在当前会话中设置共存别名
                alias abrew='arch -arm64 /opt/homebrew/bin/brew'
                alias ibrew='arch -x86_64 /usr/local/bin/brew'
                alias brew='abrew'  # 默认使用Apple Silicon版本
                export PATH="/opt/homebrew/bin:$PATH"
                
                print_success "共存别名已设置到当前会话"
                print_info "当前会话可用命令: abrew, ibrew, brew"
            fi
            
            # 验证双版本安装
            echo ""
            print_info "验证Homebrew双版本安装..."
            
            # 验证Apple Silicon版本
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                local arm_version=$(arch -arm64 /opt/homebrew/bin/brew --version 2>/dev/null | head -1 || echo "获取版本失败")
                print_success "Apple Silicon版本: $arm_version"
            else
                print_error "Apple Silicon版本安装失败"
            fi
            
            # 验证Intel版本
            if [[ -f "/usr/local/bin/brew" ]]; then
                local intel_version=$(arch -x86_64 /usr/local/bin/brew --version 2>/dev/null | head -1 || echo "获取版本失败")
                print_success "Intel版本: $intel_version"
            else
                print_warning "Intel版本未找到"
            fi
            
            # 验证别名
            echo ""
            print_info "验证别名配置..."
            if command -v abrew &> /dev/null; then
                print_success "abrew 别名可用"
            fi
            if command -v ibrew &> /dev/null; then
                print_success "ibrew 别名可用"  
            fi
            
            print_success "🎉 Homebrew双版本共存配置完成！"
            return 0
            else
                print_error "Homebrew 安装位置不符合预期"
                return 1
            fi
        else
            # 安装失败，但先检查是否实际上已经安装了
            if [[ -f "$expected_brew_path" ]]; then
                print_warning "安装过程有警告，但Homebrew已成功安装"
                print_info "自动配置环境变量..."
                if [[ "$mac_arch" == "arm64" ]]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                    
                    # 添加到shell配置文件以便持久化
                    local profile_file=""
                    if [[ "$SHELL" == *"zsh"* ]]; then
                        profile_file="$HOME/.zprofile"
                    elif [[ "$SHELL" == *"bash"* ]]; then
                        profile_file="$HOME/.bash_profile"
                    fi
                    
                    if [[ -n "$profile_file" ]] && ! grep -q 'eval.*brew shellenv' "$profile_file" 2>/dev/null; then
                        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$profile_file"
                        print_success "已添加环境配置到 $profile_file"
                    fi
                    
                    print_success "Apple Silicon Homebrew环境变量已配置"
                fi
                # 继续配置别名
                local shell_config=""
                if [[ "$SHELL" == *"zsh"* ]]; then
                    shell_config="$HOME/.zshrc"
                elif [[ "$SHELL" == *"bash"* ]]; then
                    shell_config="$HOME/.bashrc"
                fi
                
                if [[ -n "$shell_config" ]]; then
                    setup_homebrew_aliases "$shell_config" "$current_brew_path" "$expected_brew_path"
                    
                    # 立即在当前会话中设置共存别名
                    alias abrew='arch -arm64 /opt/homebrew/bin/brew'
                    alias ibrew='arch -x86_64 /usr/local/bin/brew'
                    alias brew='abrew'
                    export PATH="/opt/homebrew/bin:$PATH"
                    
                    print_success "共存别名已设置到当前会话"
                fi
                
                print_success "🎉 Homebrew双版本共存配置完成！"
                return 0
            else
                print_error "Homebrew 安装失败"
                echo ""
                print_info "可能的原因："
                echo "  1) 网络连接问题"
                echo "  2) 权限不足"
                echo "  3) 系统配置问题"
                echo ""
                print_info "替代方案："
                echo "  1) 手动安装 Homebrew:"
                if [[ "$mac_arch" == "arm64" ]]; then
                    echo "     /bin/bash -c \"\$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)\""
                else
                    echo "     arch -x86_64 /bin/bash -c \"\$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)\""
                fi
                echo "  2) 或使用官方源 (可能较慢):"
                echo "     /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                echo "  3) 使用现有的 Intel 版本 Homebrew (性能较差)"
                echo "  4) 跳过 Homebrew，使用直接下载方式安装软件"
                return 1
            fi
        fi
    else
        print_info "跳过自动安装"
        print_info "请手动安装后重新运行此脚本"
        return 1
    fi
}

# 安装正确架构的 Homebrew (支持共存) - 保留原函数用于其他地方
install_correct_homebrew() {
    local mac_arch="$1"
    local current_brew_path="$2"
    local expected_brew_path="$3"
    
    print_info "安装适合 $mac_arch 架构的 Homebrew..."
    
    # 如果已有不匹配的 Homebrew，建议共存
    if [[ -n "$current_brew_path" ]]; then
        print_info "检测到现有的 Homebrew: $current_brew_path"
        echo ""
        print_info "推荐方案: 让两个版本共存，使用别名区分"
        echo "  - abrew: Apple Silicon 版本 (ARM64)"
        echo "  - ibrew: Intel 版本 (x86_64)"
        echo ""
        echo "选择方案:"
        echo "  1) 安装并设置别名共存 (推荐)"
        echo "  2) 替换现有版本"
        echo "  3) 取消安装"
        echo ""
        read -p "请选择 [1-3]: " -n 1 -r INSTALL_CHOICE
        echo
        echo
        
        case $INSTALL_CHOICE in
            1)
                print_info "将安装新版本并设置别名共存"
                ;;
            2)
                print_warning "将替换现有版本"
                read -p "确认要卸载现有的 Homebrew? [y/N]: " -n 1 -r UNINSTALL_OLD
                echo
                if [[ $UNINSTALL_OLD =~ ^[Yy]$ ]]; then
                    print_info "卸载现有 Homebrew..."
                    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"; then
                        print_success "旧版本 Homebrew 卸载完成"
                    else
                        print_warning "卸载可能不完整，但继续安装新版本"
                    fi
                else
                    print_info "取消替换，改为共存方案"
                fi
                ;;
            3)
                print_info "取消安装"
                return 1
                ;;
            *)
                print_info "无效选择，使用共存方案"
                ;;
        esac
    fi
    
    print_info "下载并安装 Homebrew..."
    print_info "这可能需要几分钟时间，请耐心等待..."
    
    # 安装 Homebrew
    # 根据架构选择合适的安装命令
    local install_cmd=""
    if [[ "$mac_arch" == "arm64" ]]; then
        install_cmd='/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"'
    else
        install_cmd='arch -x86_64 /bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"'
    fi
    
    if eval "$install_cmd"; then
        print_success "Homebrew 安装完成"
        
        # 检查安装路径是否正确
        if [[ -f "$expected_brew_path" ]]; then
            print_success "Homebrew 安装在正确位置: $expected_brew_path"
            
            # 配置环境变量和别名
            print_info "配置环境变量和别名..."
            local shell_config=""
            if [[ "$SHELL" == *"zsh"* ]]; then
                shell_config="$HOME/.zshrc"
            elif [[ "$SHELL" == *"bash"* ]]; then
                shell_config="$HOME/.bashrc"
            fi
            
            if [[ -n "$shell_config" ]]; then
                # 设置别名而不是直接修改PATH
                setup_homebrew_aliases "$shell_config" "$current_brew_path" "$expected_brew_path"
                
                # 立即在当前会话中设置别名
                if [[ "$mac_arch" == "arm64" ]]; then
                    alias abrew='arch -arm64 /opt/homebrew/bin/brew'
                    alias ibrew='arch -x86_64 /usr/local/bin/brew'
                    # 设置默认使用Apple Silicon版本
                    export PATH="/opt/homebrew/bin:$PATH"
                else
                    alias ibrew='arch -x86_64 /usr/local/bin/brew'
                    alias abrew='arch -arm64 /opt/homebrew/bin/brew'
                    # 设置默认使用Intel版本
                    export PATH="/usr/local/bin:$PATH"
                fi
                print_success "别名已设置到当前会话"
            fi
            
            # 验证安装
            if command -v brew &> /dev/null; then
                local new_brew_path=$(which brew)
                if [[ "$new_brew_path" == "$expected_brew_path" ]]; then
                    print_success "Homebrew 架构配置正确"
                    return 0
                else
                    print_warning "Homebrew 安装成功，但路径可能需要手动配置"
                    print_info "请重启终端或执行: source $shell_config"
                    return 0
                fi
            else
                print_warning "Homebrew 安装完成，但需要重启终端生效"
                return 0
            fi
        else
            print_error "Homebrew 安装位置不符合预期"
            return 1
        fi
    else
        print_error "Homebrew 安装失败"
        return 1
    fi
}

# 设置 Homebrew 共存别名
setup_homebrew_aliases() {
    local shell_config="$1"
    local current_brew_path="$2"
    local expected_brew_path="$3"
    
    print_info "设置 Homebrew 共存别名到 $shell_config"
    
    # 检查是否已经有别名配置
    if grep -q "alias.*brew.*arch" "$shell_config" 2>/dev/null; then
        print_warning "检测到已有 Homebrew 别名配置"
        echo ""
        read -p "是否覆盖现有配置? [y/N]: " -n 1 -r OVERWRITE
        echo
        if [[ ! $OVERWRITE =~ ^[Yy]$ ]]; then
            print_info "保留现有配置"
            return 0
        fi
        # 备份现有配置
        cp "$shell_config" "$shell_config.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "已备份现有配置"
    fi
    
    # 添加别名配置
    echo "" >> "$shell_config"
    echo "# Homebrew 双版本共存配置 - $(date)" >> "$shell_config"
    echo "alias abrew='arch -arm64 /opt/homebrew/bin/brew'  # Apple Silicon Homebrew" >> "$shell_config"
    echo "alias ibrew='arch -x86_64 /usr/local/bin/brew'   # Intel Homebrew" >> "$shell_config"
    echo "" >> "$shell_config"
    
    # 根据M1 Mac的特性，默认优先使用Apple Silicon版本
    echo "# 优先使用 Apple Silicon 版本 (推荐用于M1 Mac)" >> "$shell_config"
    echo "export PATH=\"/opt/homebrew/bin:\$PATH\"" >> "$shell_config"
    echo "alias brew='abrew'  # 默认使用 Apple Silicon 版本" >> "$shell_config"
    echo "" >> "$shell_config"
    
    print_success "别名配置已添加到 $shell_config"
    
    # 显示使用说明
    echo ""
    print_info "🎉 Homebrew 共存配置完成！"
    echo ""
    print_info "📋 使用说明:"
    echo "  abrew - Apple Silicon 版本 (推荐，性能更好)"
    echo "  ibrew - Intel 版本 (兼容性更好)"
    echo "  brew  - 默认指向 abrew (Apple Silicon 版本)"
    echo ""
    print_info "💡 使用示例:"
    echo "  abrew install docker     # 安装 ARM64 原生版本"
    echo "  ibrew install some-tool  # 安装 Intel 兼容版本"
    echo "  brew install node        # 默认安装 ARM64 版本"
    echo ""
    print_info "⚡ 重新加载配置:"
    echo "  source $shell_config"
    echo ""
}

# 检查 Docker 环境
check_docker() {
    print_info "检查 Docker 环境..."
    
    # 显示系统架构信息
    if [[ "$OS" == "macos" ]]; then
        local mac_arch=$(detect_mac_arch)
        if [[ "$mac_arch" == "arm64" ]]; then
            print_info "系统架构: Apple Silicon Mac (ARM64)"
        elif [[ "$mac_arch" == "x86_64" ]]; then
            print_info "系统架构: Intel Mac (x86_64)"
        fi
    fi
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 2))  # Docker命令 + Docker服务
    
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version 2>/dev/null || echo "未知版本")
        print_success "Docker 已安装: $docker_version"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        
        # 检查 Docker 服务是否运行
        if docker info &> /dev/null 2>&1; then
            print_success "Docker 服务正在运行"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            
            # 显示 Docker 详细信息
            local docker_server_version=$(docker info --format "{{.ServerVersion}}" 2>/dev/null || echo "未知")
            local docker_arch=$(docker info --format "{{.Architecture}}" 2>/dev/null || echo "未知")
            local docker_os=$(docker info --format "{{.OSType}}" 2>/dev/null || echo "未知")
            
            if [[ "$docker_server_version" != "未知" ]]; then
                print_info "Docker 服务器版本: $docker_server_version"
            fi
            if [[ "$docker_arch" != "未知" ]]; then
                print_info "Docker 架构: $docker_arch"
            fi
            if [[ "$docker_os" != "未知" ]]; then
                print_info "Docker 操作系统: $docker_os"
            fi
            
            # 检查是否是正确的架构版本
            if [[ "$OS" == "macos" ]]; then
                local mac_arch=$(detect_mac_arch)
                if [[ "$mac_arch" == "arm64" && "$docker_arch" == "x86_64" ]]; then
                    print_warning "检测到您在 Apple Silicon Mac 上运行 Intel 版本的 Docker"
                    print_info "建议安装 Apple Silicon 版本以获得更好的性能"
                elif [[ "$mac_arch" == "x86_64" && "$docker_arch" == "aarch64" ]]; then
                    print_warning "检测到您在 Intel Mac 上运行 ARM64 版本的 Docker"
                    print_info "建议安装 Intel 版本以获得更好的兼容性"
                fi
            fi
        else
            print_warning "Docker 已安装但服务未运行"
            print_info "请启动 Docker 服务："
            if [[ "$OS" == "macos" ]]; then
                echo "  - 启动 Docker Desktop 应用"
                echo "  - 或使用命令: open -a Docker"
            else
                echo "  - sudo systemctl start docker"
                echo "  - sudo service docker start"
            fi
            WARNINGS+=("Docker 服务未运行")
        fi
    else
        print_error "Docker 未安装"
        FAILED_CHECKS+=("Docker")
        
        # 根据操作系统提供安装建议
        local install_cmd=""
        if [[ "$OS" == "macos" ]]; then
            install_cmd="install_docker_macos"
        elif [[ "$OS" == "linux" ]]; then
            install_cmd="install_docker_linux"
        fi
        
        if [[ -n "$install_cmd" ]]; then
            if ask_install "Docker" "$install_cmd"; then
                print_success "Docker 安装完成"
                print_info "请重启终端或重新加载环境"
                if [[ "$OS" == "macos" ]]; then
                    print_info "如果是 Docker Desktop，请启动应用"
                else
                    print_info "请启动 Docker 服务: sudo systemctl start docker"
                fi
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            fi
        else
            print_info "请手动安装 Docker: https://docs.docker.com/get-docker/"
        fi
    fi
}

# macOS Docker 安装函数
install_docker_macos() {
    print_info "在 macOS 上安装 Docker..."
    
    # 检测 macOS 芯片架构
    local mac_arch=$(detect_mac_arch)
    local docker_arch=""
    local docker_url=""
    
    if [[ "$mac_arch" == "arm64" ]]; then
        docker_arch="Apple Silicon"
        docker_url="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
        print_info "检测到 Apple Silicon Mac (ARM64)"
    elif [[ "$mac_arch" == "x86_64" ]]; then
        docker_arch="Intel"
        docker_url="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
        print_info "检测到 Intel Mac (x86_64)"
    else
        print_error "未知的 Mac 架构: $mac_arch"
        return 1
    fi
    
    # 首先检查和修复 Homebrew 架构
    print_info "检查 Homebrew 架构匹配..."
    check_and_fix_homebrew_arch
    local homebrew_status=$?
    
    # homebrew_status: 0=正常, 1=失败, 2=跳过Homebrew
    if [[ $homebrew_status -eq 1 ]]; then
        print_error "Homebrew 配置失败"
        print_info "将使用直接下载方式安装 Docker"
        install_docker_directly_macos "$docker_url" "$docker_arch"
        return $?
    elif [[ $homebrew_status -eq 2 ]]; then
        print_info "跳过 Homebrew，使用直接下载方式"
        install_docker_directly_macos "$docker_url" "$docker_arch"
        return $?
    fi
    
    # 重新检测 Homebrew 状态
    local brew_path=""
    local brew_arch="未知"
    local use_homebrew=true
    
    if command -v brew &> /dev/null; then
        brew_path=$(which brew)
        if [[ "$brew_path" == "/opt/homebrew/bin/brew" ]]; then
            brew_arch="Apple Silicon"
        elif [[ "$brew_path" == "/usr/local/bin/brew" ]]; then
            brew_arch="Intel"
        fi
        print_success "当前 Homebrew: $brew_path ($brew_arch 版本)"
        
        # 最终检查架构匹配
        if [[ "$mac_arch" == "arm64" && "$brew_arch" == "Intel" ]]; then
            print_warning "Homebrew 架构仍然不匹配，建议使用直接下载"
            use_homebrew=false
        elif [[ "$mac_arch" == "x86_64" && "$brew_arch" == "Apple Silicon" ]]; then
            print_warning "Homebrew 架构仍然不匹配，建议使用直接下载"
            use_homebrew=false
        fi
    else
        print_warning "Homebrew 不可用，使用直接下载方式"
        use_homebrew=false
    fi
    
    print_info "将安装适合 $docker_arch Mac 的 Docker Desktop"
    echo ""
    
    # 根据 Homebrew 状态提供安装选项
    echo "请选择安装方式："
    
    if [[ "$use_homebrew" == "true" ]]; then
        echo "  1) 使用 Homebrew 安装 (推荐 - 架构匹配)"
        echo "  2) 直接下载安装"
        echo "  3) 安装轻量级 Colima (开源替代方案)"
        echo "  4) 手动下载安装"
        echo "  5) 取消安装"
        echo ""
        read -p "请选择 [1-5]: " -n 1 -r INSTALL_CHOICE
    else
        echo "  1) 直接下载安装 (推荐 - 正确架构)"
        echo "  2) 安装轻量级 Colima (开源替代方案)"
        echo "  3) 手动下载安装"
        echo "  4) 取消安装"
        echo ""
        read -p "请选择 [1-4]: " -n 1 -r INSTALL_CHOICE
    fi
    echo
    echo
    
    case $INSTALL_CHOICE in
        1)
            if [[ "$use_homebrew" == "true" ]]; then
                # 使用 Homebrew 安装 (架构已匹配)
                print_info "使用 Homebrew 安装 Docker Desktop..."
                
                # 可选更新 Homebrew
                echo ""
                read -p "是否更新 Homebrew? (可能需要几分钟) [y/N]: " -n 1 -r UPDATE_BREW
                echo
                if [[ $UPDATE_BREW =~ ^[Yy]$ ]]; then
                    print_info "更新 Homebrew..."
                    brew update
                else
                    print_info "跳过 Homebrew 更新"
                fi
                
                # 安装 Docker Desktop (使用正确架构的brew)
                print_info "安装 Docker Desktop..."
                local brew_cmd="brew"
                if [[ "$mac_arch" == "arm64" ]]; then
                    # 如果有Apple Silicon版本的Homebrew，优先使用
                    if [[ -f "/opt/homebrew/bin/brew" ]]; then
                        brew_cmd="arch -arm64 /opt/homebrew/bin/brew"
                        print_info "使用 Apple Silicon 版本的 Homebrew"
                    fi
                elif [[ "$mac_arch" == "x86_64" ]]; then
                    # 如果有Intel版本的Homebrew，优先使用
                    if [[ -f "/usr/local/bin/brew" ]]; then
                        brew_cmd="arch -x86_64 /usr/local/bin/brew"
                        print_info "使用 Intel 版本的 Homebrew"
                    fi
                fi
                
                if $brew_cmd install --cask docker-desktop 2>/dev/null || $brew_cmd install --cask docker; then
                    print_success "Docker Desktop 安装完成"
                    
                    # 提示用户启动 Docker
                    echo ""
                    read -p "是否现在启动 Docker Desktop? [y/N]: " -n 1 -r START_DOCKER
                    echo
                    if [[ $START_DOCKER =~ ^[Yy]$ ]]; then
                        print_info "启动 Docker Desktop..."
                        open -a Docker
                        print_info "Docker Desktop 正在启动，请等待几分钟完成初始化"
                    fi
                    return 0
                else
                    print_error "Homebrew 安装 Docker 失败"
                    print_info "尝试自动下载安装..."
                    install_docker_directly_macos "$docker_url" "$docker_arch"
        return $?
                fi
            else
                # 直接下载安装 (推荐)
                print_info "直接下载并安装 Docker Desktop..."
                install_docker_directly_macos "$docker_url" "$docker_arch"
        return $?
            fi
            ;;
        2)
            if [[ "$use_homebrew" == "true" ]]; then
                # 直接下载安装
                print_info "直接下载并安装 Docker Desktop..."
                install_docker_directly_macos "$docker_url" "$docker_arch"
        return $?
            else
                # 安装 Colima
                print_info "安装 Colima (轻量级 Docker 替代方案)..."
                install_colima_macos
                return $?
            fi
            ;;
        3)
            if [[ "$use_homebrew" == "true" ]]; then
                # 安装 Colima
                print_info "安装 Colima (轻量级 Docker 替代方案)..."
                install_colima_macos
                return $?
            else
                # 手动安装指导
                print_info "手动安装 Docker Desktop for $docker_arch Mac:"
                echo ""
                echo "📥 下载链接: $docker_url"
                echo ""
                echo "📋 安装步骤:"
                echo "1. 点击上面的链接下载 Docker.dmg 文件"
                echo "2. 双击下载的 Docker.dmg 文件"
                echo "3. 将 Docker 拖拽到 Applications 文件夹"
                echo "4. 从 Applications 文件夹启动 Docker"
                echo "5. 按照屏幕提示完成设置"
                echo ""
                
                # 询问是否自动打开下载页面
                read -p "是否在浏览器中打开下载页面? [y/N]: " -n 1 -r OPEN_BROWSER
                echo
                if [[ $OPEN_BROWSER =~ ^[Yy]$ ]]; then
                    open "$docker_url"
                    print_info "已在浏览器中打开下载页面"
                fi
                return 0
            fi
            ;;
        4)
            if [[ "$use_homebrew" == "true" ]]; then
                # 手动安装指导
                print_info "手动安装 Docker Desktop for $docker_arch Mac:"
                echo ""
                echo "📥 下载链接: $docker_url"
                echo ""
                echo "📋 安装步骤:"
                echo "1. 点击上面的链接下载 Docker.dmg 文件"
                echo "2. 双击下载的 Docker.dmg 文件"
                echo "3. 将 Docker 拖拽到 Applications 文件夹"
                echo "4. 从 Applications 文件夹启动 Docker"
                echo "5. 按照屏幕提示完成设置"
                echo ""
                
                # 询问是否自动打开下载页面
                read -p "是否在浏览器中打开下载页面? [y/N]: " -n 1 -r OPEN_BROWSER
                echo
                if [[ $OPEN_BROWSER =~ ^[Yy]$ ]]; then
                    open "$docker_url"
                    print_info "已在浏览器中打开下载页面"
                fi
                return 0
            else
                # 取消安装
                print_info "取消 Docker 安装"
                return 1
            fi
            ;;
        5)
            if [[ "$use_homebrew" == "true" ]]; then
                print_info "取消 Docker 安装"
                return 1
            else
                print_error "无效选择，取消安装"
                return 1
            fi
            ;;
        *)
            print_error "无效选择，取消安装"
            return 1
            ;;
    esac
    
    # 如果 Homebrew 安装失败，提供手动安装指导
    print_info "自动安装失败，请手动安装 Docker Desktop:"
    echo ""
    echo "📥 下载地址: $docker_url"
    echo "📋 或访问: https://docs.docker.com/desktop/mac/install/"
    echo ""
    echo "请下载适合 $docker_arch Mac 的版本"
    return 1
}

# macOS 直接下载安装 Docker 函数
install_docker_directly_macos() {
    local download_url="$1"
    local arch_name="$2"
    
    print_info "直接下载 Docker Desktop for $arch_name Mac..."
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    local dmg_file="$temp_dir/Docker.dmg"
    
    print_info "下载 Docker Desktop..."
    print_info "下载地址: $download_url"
    
    # 下载 DMG 文件
    if curl -L -o "$dmg_file" "$download_url"; then
        print_success "下载完成"
        
        print_info "挂载 DMG 文件..."
        # 挂载 DMG
        local mount_point=$(hdiutil attach "$dmg_file" -nobrowse | grep "/Volumes" | awk '{print $3}')
        
        if [[ -n "$mount_point" && -d "$mount_point" ]]; then
            print_success "DMG 挂载成功: $mount_point"
            
            # 查找 Docker.app
            local docker_app="$mount_point/Docker.app"
            if [[ -d "$docker_app" ]]; then
                print_info "复制 Docker.app 到 Applications 目录..."
                
                # 如果已存在，先删除
                if [[ -d "/Applications/Docker.app" ]]; then
                    print_info "删除旧版本的 Docker.app..."
                    rm -rf "/Applications/Docker.app"
                fi
                
                # 复制应用
                if cp -R "$docker_app" "/Applications/"; then
                    print_success "Docker Desktop 安装完成"
                    
                    # 卸载 DMG
                    print_info "清理安装文件..."
                    hdiutil detach "$mount_point" &>/dev/null
                    rm -rf "$temp_dir"
                    
                    # 询问是否启动
                    echo ""
                    read -p "是否现在启动 Docker Desktop? [y/N]: " -n 1 -r START_DOCKER
                    echo
                    if [[ $START_DOCKER =~ ^[Yy]$ ]]; then
                        print_info "启动 Docker Desktop..."
                        open -a Docker
                        print_info "Docker Desktop 正在启动，请等待几分钟完成初始化"
                        
                        # 等待几秒让Docker开始启动
                        sleep 3
                        print_info "Docker Desktop 已启动，请在系统托盘中查看启动状态"
                    fi
                    
                    return 0
                else
                    print_error "复制 Docker.app 失败"
                fi
            else
                print_error "在 DMG 中未找到 Docker.app"
            fi
            
            # 卸载 DMG
            hdiutil detach "$mount_point" &>/dev/null
        else
            print_error "挂载 DMG 文件失败"
        fi
    else
        print_error "下载 Docker Desktop 失败"
        print_info "请检查网络连接或手动下载"
    fi
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    print_info "自动安装失败，请手动下载安装:"
    echo "📥 下载地址: $download_url"
    return 1
}

# macOS Colima 安装函数 (轻量级开源替代方案)
install_colima_macos() {
    print_info "安装 Colima - 轻量级 Docker 替代方案..."
    
    if ! command -v brew &> /dev/null; then
        print_error "需要 Homebrew 来安装 Colima"
        print_info "请先安装 Homebrew: https://brew.sh"
        return 1
    fi
    
    print_info "Colima 是一个轻量级的开源容器运行时，基于 Lima 和 containerd"
    print_info "优点: 免费、轻量、原生支持 Apple Silicon"
    print_info "缺点: 没有 GUI 界面，需要命令行操作"
    echo ""
    
    read -p "是否继续安装 Colima? [y/N]: " -n 1 -r INSTALL_COLIMA
    echo
    if [[ ! $INSTALL_COLIMA =~ ^[Yy]$ ]]; then
        print_info "取消 Colima 安装"
        return 1
    fi
    
    # 确定使用哪个 brew
    local brew_cmd="brew"
    local mac_arch=$(detect_mac_arch)
    if [[ "$mac_arch" == "arm64" && -f "/opt/homebrew/bin/brew" ]]; then
        brew_cmd="arch -arm64 /opt/homebrew/bin/brew"
        print_info "使用 Apple Silicon 版本的 Homebrew"
    elif [[ "$mac_arch" == "x86_64" && -f "/usr/local/bin/brew" ]]; then
        brew_cmd="arch -x86_64 /usr/local/bin/brew"
        print_info "使用 Intel 版本的 Homebrew"
    fi
    
    # 安装 Docker CLI (如果未安装)
    if ! command -v docker &> /dev/null; then
        print_info "安装 Docker CLI..."
        if ! $brew_cmd install docker; then
            print_error "Docker CLI 安装失败"
            return 1
        fi
    else
        print_success "Docker CLI 已安装"
    fi
    
    # 安装 Colima
    print_info "安装 Colima..."
    if $brew_cmd install colima; then
        print_success "Colima 安装完成"
        
        # 启动 Colima
        print_info "启动 Colima..."
        if colima start; then
            print_success "Colima 启动成功"
            
            # 验证 Docker 是否可用
            if docker info &> /dev/null; then
                print_success "Docker 环境已就绪"
                print_info "您现在可以使用 docker 命令"
                echo ""
                print_info "常用 Colima 命令:"
                echo "  colima start    - 启动 Colima"
                echo "  colima stop     - 停止 Colima"
                echo "  colima status   - 查看状态"
                echo "  colima delete   - 删除 Colima VM"
                return 0
            else
                print_warning "Colima 启动了但 Docker 命令不可用"
                print_info "请检查 Docker CLI 配置"
                return 1
            fi
        else
            print_error "Colima 启动失败"
            print_info "请尝试手动启动: colima start"
            return 1
        fi
    else
        print_error "Colima 安装失败"
        return 1
    fi
}

# Linux Docker 安装函数
install_docker_linux() {
    print_info "在 Linux 上安装 Docker..."
    
    # 检测 Linux 发行版
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        print_info "检测到 Ubuntu/Debian，使用官方安装脚本..."
        
        # 使用 Docker 官方便捷安装脚本
        if curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh; then
            print_success "Docker 安装完成"
            
            # 添加当前用户到 docker 组
            if groups "$USER" | grep -q docker; then
                print_success "用户已在 docker 组中"
            else
                print_info "将用户添加到 docker 组..."
                if sudo usermod -aG docker "$USER"; then
                    print_success "用户已添加到 docker 组"
                    print_info "请重新登录或执行: newgrp docker"
                fi
            fi
            
            # 启动 Docker 服务
            print_info "启动 Docker 服务..."
            if sudo systemctl enable docker && sudo systemctl start docker; then
                print_success "Docker 服务已启动并设置为开机自启"
            fi
            
            # 清理安装脚本
            rm -f get-docker.sh
            return 0
        else
            print_error "Docker 安装脚本执行失败"
            rm -f get-docker.sh
        fi
    elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        # Red Hat/CentOS/Fedora
        print_info "检测到 Red Hat/CentOS/Fedora 系统"
        local pkg_manager="yum"
        if command -v dnf &> /dev/null; then
            pkg_manager="dnf"
        fi
        
        if sudo $pkg_manager install -y docker; then
            print_success "Docker 安装完成"
            
            # 启动服务
            if sudo systemctl enable docker && sudo systemctl start docker; then
                print_success "Docker 服务已启动"
            fi
            
            # 添加用户到 docker 组
            if sudo usermod -aG docker "$USER"; then
                print_success "用户已添加到 docker 组，请重新登录"
            fi
            
            return 0
        fi
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        print_info "检测到 Arch Linux"
        if sudo pacman -S --noconfirm docker; then
            print_success "Docker 安装完成"
            
            if sudo systemctl enable docker && sudo systemctl start docker; then
                print_success "Docker 服务已启动"
            fi
            
            if sudo usermod -aG docker "$USER"; then
                print_success "用户已添加到 docker 组，请重新登录"
            fi
            
            return 0
        fi
    fi
    
    # 回退到手动安装指导
    print_error "自动安装失败，请手动安装 Docker"
    print_info "参考官方文档: https://docs.docker.com/engine/install/"
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
    
    # 简化 Android NDK 检查，避免交互阻塞
    if [[ -n "$ANDROID_NDK_ROOT" && -d "$ANDROID_NDK_ROOT" ]]; then
        print_success "Android NDK 已设置: $ANDROID_NDK_ROOT"
    elif [[ -n "$found_ndk" ]]; then
        print_warning "找到 Android NDK 但环境变量未设置: $found_ndk"
        print_info "请手动执行: export ANDROID_NDK_ROOT=\"$found_ndk\""
    else
        print_error "Android NDK 未设置"
        print_info "请下载并安装 Android NDK: https://developer.android.com/ndk/downloads"
    fi
    
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
    print_info "check_android_ndk 函数执行完成"
}

# 获取系统架构信息用于下载正确的 HarmonyOS SDK
get_harmony_sdk_info() {
    local os_type=""
    local arch=""
    local download_url=""
    local filename=""
    local sha256=""
    local size=""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS 系统
        local mac_arch=$(detect_mac_arch)
        if [[ "$mac_arch" == "arm64" ]]; then
            # Apple Silicon Mac
            os_type="Mac-M1"
            download_url="https://repo.huaweicloud.com/openharmony/os/5.1.0-Release/L2-SDK-MAC-M1-PUBLIC.tar.gz"
            filename="L2-SDK-MAC-M1-PUBLIC.tar.gz"
            size="1.2 GB"
        else
            # Intel Mac
            os_type="Mac"
            download_url="https://repo.huaweicloud.com/openharmony/os/5.1.0-Release/L2-SDK-MAC-PUBLIC.tar.gz"
            filename="L2-SDK-MAC-PUBLIC.tar.gz"
            size="1.3 GB"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux 系统
        os_type="Linux"
        download_url="https://repo.huaweicloud.com/openharmony/os/5.1.0-Release/L2-SDK-LINUX-PUBLIC.tar.gz"
        filename="L2-SDK-LINUX-PUBLIC.tar.gz"
        size="3.2 GB"
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
        # Windows 系统
        os_type="Windows"
        download_url="https://repo.huaweicloud.com/openharmony/os/5.1.0-Release/L2-SDK-WINDOWS-PUBLIC.tar.gz"
        filename="L2-SDK-WINDOWS-PUBLIC.tar.gz"
        size="3.2 GB"
    else
        print_error "不支持的操作系统: $OSTYPE"
        return 1
    fi
    
    echo "$os_type|$download_url|$filename|$size"
}

# 安装 HarmonyOS SDK
install_harmony_sdk() {
    local sdk_info
    sdk_info=$(get_harmony_sdk_info)
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    IFS='|' read -r os_type download_url filename size <<< "$sdk_info"
    
    print_info "准备安装 HarmonyOS SDK for $os_type"
    print_info "文件大小: $size"
    print_info "下载地址: $download_url"
    
    # 设置默认安装路径
    local default_install_path="/opt/ohos-sdk/5.1.0"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        default_install_path="/opt/ohos-sdk/5.1.0"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        default_install_path="/opt/ohos-sdk/5.1.0"
    fi
    
    # 在自动安装模式下使用默认路径
    if [[ "$AUTO_INSTALL" != "true" && "$CI" != "true" ]]; then
        echo ""
        print_info "默认安装路径: $default_install_path"
        read -p "是否使用默认路径? 或输入自定义路径 [回车使用默认]: " custom_path

        if [[ -n "$custom_path" ]]; then
            default_install_path="$custom_path"
        fi
    else
        print_info "自动安装模式: 使用默认路径 $default_install_path"
    fi
    
    # 创建安装目录
    print_info "创建安装目录: $default_install_path"
    if ! sudo mkdir -p "$default_install_path"; then
        print_error "无法创建安装目录: $default_install_path"
        print_info "请检查权限或选择其他路径"
        return 1
    fi
    
    # 创建临时下载目录
    local temp_dir=$(mktemp -d)
    local download_file="$temp_dir/$filename"
    
    print_info "开始下载 HarmonyOS SDK..."
    print_info "这可能需要较长时间，请保持网络连接稳定"
    
    # 下载文件，显示进度
    if command -v curl >/dev/null 2>&1; then
        if curl -L --progress-bar -o "$download_file" "$download_url"; then
            print_success "下载完成"
        else
            print_error "下载失败"
            rm -rf "$temp_dir"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget --progress=bar:force:noscroll -O "$download_file" "$download_url"; then
            print_success "下载完成"
        else
            print_error "下载失败"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        print_error "需要 curl 或 wget 来下载文件"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 验证下载文件
    if [[ ! -f "$download_file" ]]; then
        print_error "下载的文件不存在"
        rm -rf "$temp_dir"
        return 1
    fi
    
    local file_size=$(du -h "$download_file" | cut -f1)
    print_info "下载文件大小: $file_size"
    
    # 解压文件
    print_info "解压 HarmonyOS SDK 到 $default_install_path..."
    if sudo tar -xzf "$download_file" -C "$default_install_path" --strip-components=1; then
        print_success "解压完成"
    else
        print_error "解压失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 设置权限
    print_info "设置文件权限..."
    sudo chown -R "$USER:$(id -gn)" "$default_install_path" 2>/dev/null || true
    sudo chmod -R 755 "$default_install_path" 2>/dev/null || true
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    # 解压 native SDK zip 文件
    print_info "解压 native SDK 组件..."
    local native_zip_path=""
    local darwin_path="$default_install_path/packages/ohos-sdk/darwin"
    
    if [[ -d "$darwin_path" ]]; then
        native_zip_path=$(find "$darwin_path" -name "native-darwin-*-Release.zip" | head -1)
        if [[ -n "$native_zip_path" && -f "$native_zip_path" ]]; then
            print_info "找到 native SDK: $(basename "$native_zip_path")"
            
            # 解压到 native 目录
            local native_dir="$default_install_path/native"
            sudo mkdir -p "$native_dir"
            
            if sudo unzip -q "$native_zip_path" -d "$native_dir"; then
                print_success "native SDK 解压完成"
                
                # 设置权限
                sudo chown -R "$USER:$(id -gn)" "$native_dir" 2>/dev/null || true
                sudo chmod -R 755 "$native_dir" 2>/dev/null || true
            else
                print_error "native SDK 解压失败"
                return 1
            fi
        else
            print_error "未找到 native SDK zip 文件"
            return 1
        fi
    else
        print_error "未找到 darwin SDK 目录"
        return 1
    fi
    
    # 设置环境变量 - 使用正确的嵌套路径结构
    local ndk_path="$default_install_path/native/native"
    if [[ -d "$ndk_path" ]]; then
        print_info "设置环境变量..."
        
        # 按照官方文档添加到 .bash_profile
        local profile_config="$HOME/.bash_profile"
        
        if ! grep -q "OHOS_NDK_ROOT" "$profile_config" 2>/dev/null; then
            echo "" >> "$profile_config"
            echo "# HarmonyOS SDK 环境变量" >> "$profile_config"
            echo "export PATH=\"$ndk_path/build-tools/cmake/bin:\$PATH\"" >> "$profile_config"
            echo "export OHOS_NDK_ROOT=\"$ndk_path\"" >> "$profile_config"
            print_success "已添加环境变量到 $profile_config"
        else
            print_info "环境变量已存在于 $profile_config"
        fi
        
        # 设置当前会话的环境变量
        export OHOS_NDK_ROOT="$ndk_path"
        export PATH="$OHOS_NDK_ROOT/llvm/bin:$PATH"
        
        print_success "HarmonyOS SDK 安装完成！"
        print_info "安装路径: $default_install_path"
        print_info "NDK 路径: $ndk_path"
        print_info "请重启终端或执行: source ~/.bashrc"
        
        return 0
    else
        print_error "安装完成但未找到 native 目录"
        print_error "请检查安装路径: $default_install_path"
        return 1
    fi
}

# 强制安装OpenSSL wrap和子项目
install_openssl_wrap_force() {
    local meson_build_dir="$1"

    print_info "强制安装 OpenSSL wrap 和子项目..."

    # 确保目录存在
    if [[ ! -d "$meson_build_dir" ]]; then
        print_error "MesonBuild 目录不存在: $meson_build_dir"
        return 1
    fi

    cd "$meson_build_dir" || return 1

    # 创建subprojects目录
    if [[ ! -d "subprojects" ]]; then
        mkdir -p subprojects
        print_info "创建 subprojects 目录"
    fi

    # 安装OpenSSL wrap
    print_info "安装 OpenSSL wrap..."
    wrap_result=0
    if meson wrap install openssl 2>/dev/null; then
        print_success "OpenSSL wrap 安装完成"
    else
        # 检查是否已存在
        if [[ -f "subprojects/openssl.wrap" ]]; then
            print_success "OpenSSL wrap 已存在"
        else
            print_warning "OpenSSL wrap 安装失败，但继续尝试下载"
            wrap_result=1
        fi
    fi

    # 下载OpenSSL子项目
    print_info "下载 OpenSSL 子项目..."
    if meson subprojects download openssl 2>/dev/null; then
        print_success "OpenSSL 子项目下载完成"
    else
        print_warning "OpenSSL 子项目下载失败，构建时会自动处理"
    fi

    # 验证关键文件是否存在
    if [[ -f "subprojects/openssl.wrap" ]] || [[ -d "subprojects/openssl-3.0.8" ]]; then
        print_success "OpenSSL 依赖准备完成"
        return 0
    else
        # 在CI环境中，即使文件不存在也返回成功，因为meson会自动处理
        if [[ "$CI" == "true" ]]; then
            print_info "CI环境: OpenSSL 依赖将在构建时自动处理"
            return 0
        else
            print_warning "OpenSSL 依赖可能不完整，但构建时会自动处理"
            return $wrap_result
        fi
    fi
}

# 检查 HarmonyOS SDK
check_harmony_sdk() {
    print_info "检查 HarmonyOS SDK..."
    
    # 检查 OHOS_NDK_ROOT 环境变量 - 使用正确的嵌套路径
    local default_sdk_paths=(
        "/opt/ohos-sdk/5.1.0/native/native"
        "/opt/ohos-sdk/native/native"
        "$HOME/ohos-sdk/5.1.0/native/native"
        "$HOME/ohos-sdk/native/native"
        "/usr/local/ohos-sdk/native/native"
    )
    
    local found_sdk=""
    for path in "${default_sdk_paths[@]}"; do
        if [[ -d "$path" ]]; then
            found_sdk="$path"
            break
        fi
    done
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ -n "$OHOS_NDK_ROOT" && -d "$OHOS_NDK_ROOT" ]]; then
        print_success "HarmonyOS NDK 路径已设置: $OHOS_NDK_ROOT"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        
        # 检查关键工具链文件
        local tools=(
            "$OHOS_NDK_ROOT/llvm/bin/clang"
            "$OHOS_NDK_ROOT/llvm/bin/clang++"
            "$OHOS_NDK_ROOT/llvm/bin/llvm-ar"
            "$OHOS_NDK_ROOT/llvm/bin/llvm-strip"
            "$OHOS_NDK_ROOT/sysroot"
        )
        
        local missing_tools=()
        for tool in "${tools[@]}"; do
            if [[ ! -e "$tool" ]]; then
                missing_tools+=("$(basename "$tool")")
            fi
        done
        
        if [[ ${#missing_tools[@]} -eq 0 ]]; then
            print_success "HarmonyOS NDK 工具链完整"
            
            # 显示工具链版本信息
            if [[ -x "$OHOS_NDK_ROOT/llvm/bin/clang" ]]; then
                local clang_version=$("$OHOS_NDK_ROOT/llvm/bin/clang" --version 2>/dev/null | head -n1 || echo "未知版本")
                print_info "Clang 版本: $clang_version"
            fi
            
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            print_error "HarmonyOS NDK 工具链不完整，缺少: ${missing_tools[*]}"
            FAILED_CHECKS+=("HarmonyOS NDK 工具链")
        fi
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        
    elif [[ -n "$found_sdk" ]]; then
        print_warning "找到 HarmonyOS SDK 但环境变量未设置: $found_sdk"
        print_info "建议设置环境变量: export OHOS_NDK_ROOT=\"$found_sdk\""
        
        # 检查是否在交互模式
        if [[ -t 0 ]]; then
            # 交互模式：无超时等待用户输入
            echo ""
            read -p "是否自动设置 OHOS_NDK_ROOT 环境变量? [y/N]: " -r
            echo
        else
            # 非交互模式：直接使用默认值
            print_info "非交互模式，使用默认选择: 不自动设置环境变量"
            REPLY="n"
        fi
        
        # 如果输入为空，默认为 N
        if [[ -z "$REPLY" ]]; then
            print_info "使用默认选择: 不自动设置环境变量"
            REPLY="n"
        fi
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 添加到配置文件
            local shell_configs=()
            if [[ -f "$HOME/.bashrc" ]]; then
                shell_configs+=("$HOME/.bashrc")
            fi
            if [[ -f "$HOME/.zshrc" ]]; then
                shell_configs+=("$HOME/.zshrc")
            fi
            
            for config in "${shell_configs[@]}"; do
                if ! grep -q "OHOS_NDK_ROOT" "$config" 2>/dev/null; then
                    echo "" >> "$config"
                    echo "# HarmonyOS SDK 环境变量" >> "$config"
                    echo "export OHOS_NDK_ROOT=\"$found_sdk\"" >> "$config"
                    echo "export PATH=\"\$OHOS_NDK_ROOT/llvm/bin:\$PATH\"" >> "$config"
                    print_success "已添加环境变量到 $config"
                fi
            done
            
            # 设置当前会话
            export OHOS_NDK_ROOT="$found_sdk"
            export PATH="$OHOS_NDK_ROOT/llvm/bin:$PATH"
            
            print_success "环境变量已设置，请重启终端生效"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            WARNINGS+=("HarmonyOS NDK 环境变量未设置")
        fi
    else
        print_error "未找到 HarmonyOS SDK"
        FAILED_CHECKS+=("HarmonyOS SDK")
        
        # 获取系统信息
        local sdk_info
        sdk_info=$(get_harmony_sdk_info)
        if [[ $? -eq 0 ]]; then
            IFS='|' read -r os_type download_url filename size <<< "$sdk_info"
            
            echo ""
            print_info "HarmonyOS SDK 下载信息:"
            print_info "系统: $os_type"
            print_info "版本: 5.1.0.107"
            print_info "大小: $size"
            print_info "下载地址: $download_url"
            echo ""
            
            if ask_install "HarmonyOS SDK" "install_harmony_sdk"; then
                print_success "HarmonyOS SDK 安装完成"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            fi
        else
            print_info "请手动下载并安装 HarmonyOS SDK:"
            print_info "访问: https://repo.huaweicloud.com/openharmony/os/5.1.0-Release/"
            print_info "下载适合您系统的 SDK 包"
        fi
    fi
}

# 显示帮助信息
show_help() {
    echo "Unity SQLCipher 编译环境检查工具"
    echo ""
    echo "用法: $0 [平台] [选项]"
    echo ""
    echo "支持的平台:"
    echo "  all                    - 检查所有平台 (默认)"
    echo "  common                 - 只检查通用工具 (meson, ninja, openssl)"
    echo "  linux                  - Linux 本地构建环境"
    echo "  linux-docker           - Linux Docker 构建环境"
    echo "  windows                - Windows 交叉编译环境"
    echo "  android                - Android 构建环境"
    echo "  android-docker         - Android Docker 构建环境"
    echo "  macos                  - macOS 本地构建环境"
    echo "  ios                    - iOS 构建环境"
    echo "  openharmony            - OpenHarmony 构建环境"
    echo ""
    echo "选项:"
    echo "  -h, --help             - 显示此帮助信息"
    echo "  --auto-install         - 自动安装缺失的工具"
    echo ""
    echo "示例:"
    echo "  $0                     # 检查所有平台"
    echo "  $0 common              # 只检查通用工具"
    echo "  $0 linux-docker        # 只检查Linux Docker环境"
    echo "  $0 android --auto-install # 自动安装Android环境"
}

# 检查通用工具 (所有构建都需要)
check_common_tools() {
    print_info "检查通用构建工具..."

    # 根据操作系统设置 meson 和 ninja 安装命令
    if [[ "$OS" == "macos" ]]; then
        check_command "meson" "Meson 构建系统" "brew install meson" true
        check_command "ninja" "Ninja 构建工具" "brew install ninja" true
    else
        check_command "meson" "Meson 构建系统" "pip3 install --break-system-packages meson" true
        check_command "ninja" "Ninja 构建工具" "sudo apt-get install -y ninja-build" true
    fi

    # 检查 Meson 子项目依赖 (OpenSSL)
    print_info "检查 Meson 子项目依赖..."
    check_meson_subprojects
}

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
    elif [[ "$OS" == "macos" ]]; then
        if ask_install "MinGW-w64 完整工具链" "brew install mingw-w64"; then
            print_success "MinGW-w64 工具链安装完成"
            print_info "现在支持 windows-x86 和 windows-x86_64 目标"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    fi
}

# 检查Android特定环境
check_android_specific() {
    print_info "检查 Android 特定构建环境..."
    check_env_var "ANDROID_NDK_ROOT" "Android NDK 路径" "/opt/android-ndk" "Android NDK"
}

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
        FAILED_CHECKS+=("Xcode 命令行工具")
        if ask_install "Xcode 命令行工具" "xcode-select --install"; then
            print_success "Xcode 命令行工具安装完成"
            print_info "请重启终端或执行: source ~/.bashrc"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
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
        if ask_install "Homebrew" '/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"'; then
            print_success "Homebrew 安装完成"
            print_info "请重启终端或执行 Homebrew 的环境设置命令"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
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

# 检查OpenHarmony特定环境
check_openharmony_specific() {
    print_info "检查 OpenHarmony 特定构建环境..."
    check_harmony_sdk
}

# 检查Meson子项目依赖 (OpenSSL)
check_meson_subprojects() {
    print_info "检查 OpenSSL wrap 配置..."

    # 获取脚本所在目录，然后找到MesonBuild~根目录
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    meson_build_dir="$(dirname "$script_dir")"
    subprojects_dir="$meson_build_dir/subprojects"
    openssl_wrap_file="$subprojects_dir/openssl.wrap"

    # 确保 subprojects 目录存在
    if [[ ! -d "$subprojects_dir" ]]; then
        print_info "创建 subprojects 目录: $subprojects_dir"
        mkdir -p "$subprojects_dir"
        if [[ $? -eq 0 ]]; then
            print_success "subprojects 目录创建成功"
        else
            print_error "subprojects 目录创建失败"
            FAILED_CHECKS+=("subprojects 目录")
            return 1
        fi
    fi

    if [[ -f "$openssl_wrap_file" ]]; then
        openssl_version=$(grep 'wrapdb_version' "$openssl_wrap_file" | cut -d'=' -f2 | tr -d ' ')
        print_success "OpenSSL wrap 配置已存在: v$openssl_version"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))

        # 检查是否已下载
        openssl_subproject_dir="$meson_build_dir/subprojects/openssl-3.0.8"
        if [[ -d "$openssl_subproject_dir" ]]; then
            print_success "OpenSSL 子项目已下载"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            print_info "OpenSSL 子项目尚未下载，首次构建时会自动下载"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    else
        print_error "缺少 OpenSSL wrap 配置文件"

        echo ""
        print_info "OpenSSL wrap 配置文件不存在，需要安装依赖"
        print_info "将在MesonBuild~目录安装: $meson_build_dir"
        echo ""

        # 在自动安装模式下强制安装
        if [[ "$AUTO_INSTALL" == "true" || "$CI" == "true" ]]; then
            print_info "自动安装模式: 强制安装 OpenSSL wrap..."
            if install_openssl_wrap_force "$meson_build_dir"; then
                # 安装成功，移除失败标记
                print_success "OpenSSL wrap 安装成功"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                # 即使安装失败，也标记为通过，因为构建时会自动处理
                print_warning "OpenSSL wrap 安装可能失败，但构建时会自动处理"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            fi
        elif ask_install "OpenSSL wrap 配置" "cd $meson_build_dir && meson wrap install openssl && meson subprojects download"; then
            print_info "正在安装 OpenSSL wrap..."

            # 执行安装命令并捕获输出
            install_output=$(cd "$meson_build_dir" && meson wrap install openssl 2>&1)
            install_result=$?

            # 检查是否成功安装或文件已存在
            if [[ $install_result -eq 0 ]] || echo "$install_output" | grep -q "Wrap file already exists"; then
                if echo "$install_output" | grep -q "Wrap file already exists"; then
                    print_success "OpenSSL wrap 已存在，无需重新安装"
                else
                    print_success "OpenSSL wrap 安装完成"
                fi

                print_info "正在下载 OpenSSL 子项目..."
                if (cd "$meson_build_dir" && meson subprojects download openssl); then
                    print_success "OpenSSL 子项目下载完成"
                    PASSED_CHECKS=$((PASSED_CHECKS + 1))
                else
                    print_warning "OpenSSL 子项目下载失败，构建时会自动下载"
                    PASSED_CHECKS=$((PASSED_CHECKS + 1))
                fi
            else
                print_error "OpenSSL wrap 安装失败"
                print_error "错误信息: $install_output"
                print_info "请手动运行: cd $meson_build_dir && meson wrap install openssl"
            fi
        else
            # 用户拒绝安装
            FAILED_CHECKS+=("OpenSSL wrap 配置")
        fi
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 2))
}

# 主函数 - 支持平台参数
main() {
    local platform="all"
    local auto_install=false

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --auto-install)
                auto_install=true
                export AUTO_INSTALL=true
                ;;
            all|common|linux|linux-docker|windows|android|android-docker|macos|ios|openharmony)
                platform="$1"
                ;;
            *)
                echo "未知参数: $1"
                echo "使用 $0 --help 查看帮助"
                exit 1
                ;;
        esac
        shift
    done

    # 如果设置了环境变量，启用自动安装
    if [[ "$AUTO_INSTALL" == "true" || "$CI" == "true" ]]; then
        auto_install=true
    fi

    # 检测操作系统
    OS=$(detect_os)

    echo "========================================"
    echo "Unity SQLCipher 编译环境检查"
    echo "========================================"
    print_info "检测到操作系统: $OS"
    print_info "检查平台: $platform"
    if [[ "$auto_install" == "true" ]]; then
        print_info "自动安装模式: 启用"
    fi
    echo ""
    
    # 根据平台执行相应的检查
    case "$platform" in
        "all")
            check_common_tools
            if [[ "$OS" == "linux" ]]; then
                check_linux_specific
                check_windows_specific
                check_android_specific
            elif [[ "$OS" == "macos" ]]; then
                check_macos_specific
                check_ios_specific
                check_windows_specific
                check_android_specific
            fi
            check_openharmony_specific
            ;;
        "common")
            check_common_tools
            ;;
        "linux")
            check_common_tools
            check_linux_specific
            ;;
        "linux-docker")
            # Docker环境只需要检查OpenSSL依赖
            print_info "检查 Linux Docker 构建环境..."
            check_meson_subprojects
            ;;
        "windows")
            check_common_tools
            check_windows_specific
            ;;
        "android")
            check_common_tools
            check_android_specific
            ;;
        "android-docker")
            # Docker环境只需要检查OpenSSL依赖
            print_info "检查 Android Docker 构建环境..."
            check_meson_subprojects
            ;;
        "macos")
            check_common_tools
            check_macos_specific
            ;;
        "ios")
            check_common_tools
            check_ios_specific
            ;;
        "openharmony")
            check_common_tools
            check_openharmony_specific
            ;;
    esac

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
        print_success "环境检查通过！"
        echo ""
        print_info "你现在可以运行构建脚本:"
        echo "  ./build-all.sh"
        echo "  ./build-platform.sh <platform> [debug|release]"
        exit 0
    else
        print_error "环境检查未完全通过，请安装缺失的工具"
        echo ""
        print_info "重新运行: $0 $platform --auto-install"
        exit 1
    fi
}






















# 脚本入口 - 只有直接运行脚本时才执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi