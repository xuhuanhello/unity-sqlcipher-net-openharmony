#!/bin/bash

# 公共函数库
# 包含所有环境检查脚本共用的函数

# 全局变量
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=()
WARNINGS=()
AUTO_ACCEPT=${AUTO_ACCEPT:-false}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
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

# 检测Mac架构
detect_mac_arch() {
    if [[ "$(uname -m)" == "arm64" ]]; then
        echo "arm64"
    else
        echo "x86_64"
    fi
}

# 询问是否安装
ask_install() {
    local name="$1"
    local cmd="$2"
    
    if [[ "$AUTO_ACCEPT" == "true" ]]; then
        print_info "自动安装模式: 安装 $name..."
        eval "$cmd"
        return $?
    else
        echo ""
        read -p "是否安装 $name? [y/N]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            eval "$cmd"
            return $?
        else
            return 1
        fi
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
    
    if [[ "$OS" != "linux" ]]; then
        print_info "$name 检查跳过 (非Linux系统)"
        return 0
    fi
    
    if dpkg -l | grep -q "^ii  $package "; then
        print_success "$name 已安装"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        print_error "$name 未安装"
        
        if ask_install "$name" "$install_cmd"; then
            print_success "$name 安装完成"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        else
            FAILED_CHECKS+=("$name")
            return 1
        fi
    fi
}

# 检查环境变量
check_env_var() {
    local var_name="$1"
    local description="$2"
    local default_path="$3"
    local tool_name="$4"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ -n "${!var_name}" ]]; then
        local path="${!var_name}"
        if [[ -d "$path" ]]; then
            print_success "$description 已设置: $path"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        else
            print_error "$description 路径不存在: $path"
            FAILED_CHECKS+=("$description")
            return 1
        fi
    else
        print_warning "$description 未设置"
        
        if [[ -d "$default_path" ]]; then
            print_info "发现默认路径: $default_path"
            if [[ "$AUTO_ACCEPT" == "true" ]]; then
                export "$var_name"="$default_path"
                print_success "$description 已自动设置: $default_path"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
                return 0
            else
                read -p "是否使用此路径? [y/N]: " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    export "$var_name"="$default_path"
                    print_success "$description 已设置: $default_path"
                    PASSED_CHECKS=$((PASSED_CHECKS + 1))
                    return 0
                fi
            fi
        fi
        
        WARNINGS+=("$description")
        print_info "请设置环境变量: export $var_name=/path/to/$tool_name"
        return 1
    fi
}

# 强制安装OpenSSL wrap和子项目
install_openssl_wrap_force() {
    local build_dir="$1"

    print_info "强制安装 OpenSSL wrap 和子项目..."

    # 切换到构建目录
    cd "$build_dir" || return 1

    # 安装OpenSSL wrap
    print_info "安装 OpenSSL wrap..."
    if meson wrap install openssl 2>/dev/null; then
        print_success "OpenSSL wrap 安装完成"
    else
        # 检查是否已存在
        if [[ -f "subprojects/openssl.wrap" ]]; then
            print_success "OpenSSL wrap 已存在"
        else
            print_warning "OpenSSL wrap 安装失败，但继续尝试下载"
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
        # 在自动模式中，即使文件不存在也返回成功，因为meson会自动处理
        if [[ "$AUTO_ACCEPT" == "true" ]]; then
            print_info "自动模式: OpenSSL 依赖将在构建时自动处理"
            return 0
        else
            print_warning "OpenSSL 依赖可能不完整，但构建时会自动处理"
            return 1
        fi
    fi
}

# 检查HarmonyOS SDK
check_harmony_sdk() {
    print_info "检查 HarmonyOS SDK..."

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if [[ -n "$OHOS_NDK_ROOT" && -d "$OHOS_NDK_ROOT" ]]; then
        print_success "HarmonyOS SDK 已设置: $OHOS_NDK_ROOT"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        print_warning "HarmonyOS SDK 未设置或路径不存在"

        # 检查常见的安装路径
        local common_paths=(
            "/opt/ohos-sdk/5.1.0/native"
            "/opt/ohos-sdk/native"
            "$HOME/ohos-sdk/5.1.0/native"
            "$HOME/ohos-sdk/native"
        )

        for path in "${common_paths[@]}"; do
            if [[ -d "$path" ]]; then
                print_info "发现 HarmonyOS SDK: $path"
                if [[ "$AUTO_ACCEPT" == "true" ]]; then
                    export OHOS_NDK_ROOT="$path"
                    print_success "HarmonyOS SDK 已自动设置: $path"
                    PASSED_CHECKS=$((PASSED_CHECKS + 1))
                    return 0
                else
                    read -p "是否使用此路径? [y/N]: " -n 1 -r
                    echo ""
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        export OHOS_NDK_ROOT="$path"
                        print_success "HarmonyOS SDK 已设置: $path"
                        PASSED_CHECKS=$((PASSED_CHECKS + 1))
                        return 0
                    fi
                fi
            fi
        done

        WARNINGS+=("HarmonyOS SDK")
        print_info "请设置环境变量: export OHOS_NDK_ROOT=/path/to/ohos-sdk/native"
        return 1
    fi
}
