#!/bin/bash

# OpenSSL 子项目 HarmonyOS 支持修复脚本
# 自动为 OpenSSL 子项目添加 HarmonyOS 支持

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OPENSSL_MESON_FILE="$PROJECT_ROOT/subprojects/openssl-3.0.8/meson.build"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

echo "========================================"
echo "OpenSSL 子项目 HarmonyOS 支持修复"
echo "========================================"

if [[ ! -f "$OPENSSL_MESON_FILE" ]]; then
    print_warning "OpenSSL 子项目文件不存在: $OPENSSL_MESON_FILE"
    print_info "可能的原因："
    print_info "  1. 这是首次构建，子项目尚未下载"
    print_info "  2. 子项目被清理了"
    echo ""
    print_info "解决方案："
    print_info "  1. 运行 'meson subprojects download' 下载子项目"
    print_info "  2. 或者直接运行构建命令，Meson 会自动下载"
    exit 1
fi

print_info "检查 OpenSSL 子项目 HarmonyOS 支持状态..."

# 检查是否已经包含 harmony 支持
if grep -q "is_linux = host_machine.system() in \['linux', 'android', 'harmony'\]" "$OPENSSL_MESON_FILE"; then
    print_success "OpenSSL 子项目已经支持 HarmonyOS，无需修复"
    exit 0
fi

print_info "正在修复 OpenSSL 子项目..."

# 备份原文件
BACKUP_FILE="$OPENSSL_MESON_FILE.backup.$(date +%Y%m%d_%H%M%S)"
cp "$OPENSSL_MESON_FILE" "$BACKUP_FILE"
print_info "已备份原始文件: $BACKUP_FILE"

# 应用修复
if sed -i.tmp "s/is_linux = host_machine.system() in \['linux', 'android'\]/is_linux = host_machine.system() in ['linux', 'android', 'harmony']/" "$OPENSSL_MESON_FILE"; then
    rm -f "$OPENSSL_MESON_FILE.tmp"
    print_success "OpenSSL 子项目修复完成！"
    print_info "修改内容: 将 HarmonyOS 添加到 Linux 系统列表中"
    print_info "现在 OpenSSL 会将 HarmonyOS 视为 Linux 变种进行编译"
else
    print_warning "修复失败，恢复备份文件..."
    mv "$BACKUP_FILE" "$OPENSSL_MESON_FILE"
    exit 1
fi

echo ""
print_success "🎉 修复完成！现在可以正常构建 HarmonyOS 版本的库了"
