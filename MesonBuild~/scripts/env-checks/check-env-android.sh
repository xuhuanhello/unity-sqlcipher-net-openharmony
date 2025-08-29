#!/bin/bash

# Android平台检查模块
# 检查Android特定的构建环境：Android NDK

# 导入公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

# 检查Android特定环境
check_android_specific() {
    print_info "检查 Android 特定构建环境..."
    check_env_var "ANDROID_NDK_ROOT" "Android NDK 路径" "/opt/android-ndk" "Android NDK"
}
