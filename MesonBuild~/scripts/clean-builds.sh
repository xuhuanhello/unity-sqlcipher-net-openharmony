#!/bin/bash

# 清理构建目录脚本
# 用法: ./clean-builds.sh [platform-pattern]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

PATTERN="${1:-*}"

# 显示帮助信息
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "清理构建目录脚本"
    echo ""
    echo "用法: $0 [platform-pattern]"
    echo ""
    echo "参数:"
    echo "  platform-pattern  要清理的平台模式 (默认: 所有平台)"
    echo ""
    echo "示例:"
    echo "  $0                    # 清理所有构建目录"
    echo "  $0 ios                # 清理所有iOS构建目录"
    echo "  $0 ios-arm64          # 清理特定iOS平台"
    echo "  $0 android            # 清理所有Android构建目录"
    echo "  $0 windows            # 清理所有Windows构建目录"
    echo ""
    echo "支持的平台模式:"
    echo "  ios, android, windows, linux, macos"
    exit 0
fi

cd "$PROJECT_ROOT"

# 查找匹配的构建目录和 .meta 文件
if [[ "$PATTERN" == "*" ]]; then
    BUILD_PATTERN="build-*"
    echo "🧹 清理所有构建目录和 .meta 文件..."
else
    BUILD_PATTERN="build-${PATTERN}*"
    echo "🧹 清理匹配 '$PATTERN' 的构建目录和 .meta 文件..."
fi

# 检查构建目录和 .meta 文件
EXISTING_DIRS=()
EXISTING_METAS=()
TOTAL_SIZE=0

# 查找构建目录
for item in $BUILD_PATTERN; do
    if [[ -d "$item" ]]; then
        EXISTING_DIRS+=("$item")
        if command -v du >/dev/null; then
            size=$(du -sm "$item" 2>/dev/null | cut -f1 || echo "0")
            TOTAL_SIZE=$((TOTAL_SIZE + size))
        fi
    fi
done

# 查找 .meta 文件（独立查找，不依赖构建目录）
for meta in ${BUILD_PATTERN}.meta; do
    if [[ -f "$meta" ]]; then
        EXISTING_METAS+=("$meta")
    fi
done

if [[ ${#EXISTING_DIRS[@]} -eq 0 && ${#EXISTING_METAS[@]} -eq 0 ]]; then
    echo "ℹ️  没有找到匹配的构建目录或 .meta 文件"
    exit 0
fi

# 显示将要清理的目录
echo ""
if [[ ${#EXISTING_DIRS[@]} -gt 0 ]]; then
    echo "📁 找到以下构建目录:"
    for dir in "${EXISTING_DIRS[@]}"; do
        if command -v du >/dev/null; then
            size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "未知")
            echo "  - $dir ($size)"
        else
            echo "  - $dir"
        fi
    done
fi

if [[ ${#EXISTING_METAS[@]} -gt 0 ]]; then
    echo "📄 找到以下 .meta 文件:"
    for meta in "${EXISTING_METAS[@]}"; do
        echo "  - $meta"
    done
fi

if [[ $TOTAL_SIZE -gt 0 ]]; then
    echo ""
    echo "💾 总大小: ${TOTAL_SIZE}MB"
fi

# 确认删除
echo ""
read -p "❓ 确认删除这些目录吗? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 取消清理操作"
    exit 0
fi

# 执行清理
echo ""
echo "🗑️  开始清理..."
deleted_count=0

# 删除构建目录
for dir in "${EXISTING_DIRS[@]}"; do
    echo "  删除目录: $dir"
    rm -rf "$dir"
    deleted_count=$((deleted_count + 1))
done

# 删除 .meta 文件
for meta in "${EXISTING_METAS[@]}"; do
    echo "  删除文件: $meta"
    rm -f "$meta"
    deleted_count=$((deleted_count + 1))
done

echo ""
echo "✅ 清理完成!"
echo "📊 删除了 $deleted_count 个项目"
if [[ $TOTAL_SIZE -gt 0 ]]; then
    echo "💾 释放了约 ${TOTAL_SIZE}MB 空间"
fi

# iOS特殊提示
if [[ "$PATTERN" == *"ios"* || "$PATTERN" == "*" ]]; then
    echo ""
    echo "💡 iOS构建提示:"
    echo "   - iOS构建会生成Framework格式 (.framework)"
    echo "   - 如果需要重新构建，现有Framework仍然可用"
    echo "   - Framework位置: ../Plugins/lib/ios*/CRSQLCipher.framework"
fi
