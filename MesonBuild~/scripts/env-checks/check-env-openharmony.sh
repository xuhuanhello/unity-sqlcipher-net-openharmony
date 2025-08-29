#!/bin/bash

# OpenHarmony平台检查模块
# 检查OpenHarmony特定的构建环境：HarmonyOS SDK

# 导入公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

# 检查OpenHarmony特定环境
check_openharmony_specific() {
    print_info "检查 OpenHarmony 特定构建环境..."
    check_harmony_sdk

    # 执行OpenSSL HarmonyOS支持修复
    fix_openssl_harmony_support
}

# 修复OpenSSL对HarmonyOS的支持
fix_openssl_harmony_support() {
    print_info "检查 OpenSSL HarmonyOS 支持..."

    local fix_script="$SCRIPT_DIR/../fix-openssl-harmony.sh"

    if [[ ! -f "$fix_script" ]]; then
        print_warning "OpenSSL修复脚本不存在: $fix_script"
        return 1
    fi

    # 检查OpenSSL子项目是否存在
    local openssl_meson_file="$(dirname "$SCRIPT_DIR")/subprojects/openssl-3.0.8/meson.build"

    if [[ ! -f "$openssl_meson_file" ]]; then
        print_info "OpenSSL子项目尚未下载，跳过修复"
        print_info "构建时会自动下载并修复"
        return 0
    fi

    # 检查是否已经修复
    if grep -q "is_linux = host_machine.system() in \['linux', 'android', 'harmony'\]" "$openssl_meson_file"; then
        print_success "OpenSSL已支持HarmonyOS"
        return 0
    fi

    # 执行修复脚本
    print_info "正在修复OpenSSL HarmonyOS支持..."
    if bash "$fix_script"; then
        print_success "OpenSSL HarmonyOS支持修复完成"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_warning "OpenSSL HarmonyOS支持修复失败"
        WARNINGS+=("OpenSSL HarmonyOS支持")
    fi

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}
