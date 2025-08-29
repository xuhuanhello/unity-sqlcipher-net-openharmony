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
}
