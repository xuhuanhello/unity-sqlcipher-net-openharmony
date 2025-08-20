#!/bin/bash

# 构建单个平台的脚本
# 用法: ./build-platform.sh <platform> [debug|release]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

PLATFORM="$1"
BUILD_TYPE="${2:-release}"

if [[ -z "$PLATFORM" ]]; then
    echo "用法: $0 <platform> [debug|release]"
    echo ""
    echo "支持的平台:"
    echo "  windows-x86_64     - Windows 64位"
    echo "  windows-x86        - Windows 32位"
    echo "  windows-arm64      - Windows ARM64"
    echo "  linux-x86_64       - Linux 64位"
    echo "  macos-universal    - macOS 通用二进制"
    echo "  android-arm64      - Android ARM64"
    echo "  android-arm32      - Android ARM32"
    echo "  android-x86_64     - Android x86_64"
    echo "  android-x86        - Android x86"
    exit 1
fi

# 检查交叉编译文件是否存在
CROSS_FILE="$PROJECT_ROOT/cross-files/$PLATFORM.ini"
if [[ ! -f "$CROSS_FILE" ]]; then
    echo "错误: 找不到交叉编译文件 $CROSS_FILE"
    exit 1
fi

# 设置构建目录
BUILD_DIR="$PROJECT_ROOT/build-$PLATFORM"

# 清理之前的构建
if [[ -d "$BUILD_DIR" ]]; then
    echo "清理之前的构建目录 $BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi

# 设置构建类型
if [[ "$BUILD_TYPE" == "debug" ]]; then
    BUILD_TYPE_OPTION="--buildtype=debug"
else
    BUILD_TYPE_OPTION="--buildtype=release"
fi

# 检查 Android NDK (如果构建 Android 平台)
if [[ "$PLATFORM" == android-* ]]; then
    if [[ -z "$ANDROID_NDK_ROOT" ]]; then
        echo "错误: 构建 Android 平台需要设置 ANDROID_NDK_ROOT 环境变量"
        exit 1
    fi
    
    # 替换交叉编译文件中的环境变量
    TEMP_CROSS_FILE="/tmp/android-cross-$PLATFORM.ini"
    sed "s|\$ANDROID_NDK_ROOT|$ANDROID_NDK_ROOT|g" "$CROSS_FILE" > "$TEMP_CROSS_FILE"
    CROSS_FILE="$TEMP_CROSS_FILE"
    
    # 设置 Android ABI
    case "$PLATFORM" in
        android-arm64)   ANDROID_ABI="arm64-v8a" ;;
        android-arm32)   ANDROID_ABI="armeabi-v7a" ;;
        android-x86_64)  ANDROID_ABI="x86_64" ;;
        android-x86)     ANDROID_ABI="x86" ;;
    esac
    
    ANDROID_OPTIONS="-Dandroid_build=true -Dandroid_abi=$ANDROID_ABI"
else
    ANDROID_OPTIONS=""
fi

echo "开始构建 $PLATFORM ($BUILD_TYPE 模式)..."

# 配置构建
cd "$PROJECT_ROOT"
meson setup "$BUILD_DIR" \
    --cross-file="$CROSS_FILE" \
    $BUILD_TYPE_OPTION \
    $ANDROID_OPTIONS

# 构建
meson compile -C "$BUILD_DIR"

# 清理临时文件
if [[ "$PLATFORM" == android-* && -f "$TEMP_CROSS_FILE" ]]; then
    rm -f "$TEMP_CROSS_FILE"
fi

echo "构建完成: $PLATFORM"