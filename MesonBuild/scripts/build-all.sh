#!/bin/bash

# 构建所有平台的脚本
# 用法: ./build-all.sh [debug|release] [platform-group]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUILD_TYPE="${1:-release}"
PLATFORM_GROUP="${2:-all}"

echo "开始批量构建 ($BUILD_TYPE 模式)..."

# 定义平台组
ALL_PLATFORMS=(
    "windows-x86_64"
    "windows-x86"
    "windows-arm64"
    "linux-x86_64"
    "macos-universal"
    "android-arm64"
    "android-arm32"
    "android-x86_64"
    "android-x86"
)

ANDROID_PLATFORMS=(
    "android-arm64"
    "android-arm32"
    "android-x86_64"
    "android-x86"
)

WINDOWS_PLATFORMS=(
    "windows-x86_64"
    "windows-x86"
    "windows-arm64"
)

LINUX_PLATFORMS=(
    "linux-x86_64"
)

MACOS_PLATFORMS=(
    "macos-universal"
)

# 选择要构建的平台
case "$PLATFORM_GROUP" in
    "all")
        PLATFORMS=("${ALL_PLATFORMS[@]}")
        ;;
    "android")
        PLATFORMS=("${ANDROID_PLATFORMS[@]}")
        ;;
    "windows")
        PLATFORMS=("${WINDOWS_PLATFORMS[@]}")
        ;;
    "linux")
        PLATFORMS=("${LINUX_PLATFORMS[@]}")
        ;;
    "macos")
        PLATFORMS=("${MACOS_PLATFORMS[@]}")
        ;;
    *)
        echo "错误: 未知的平台组 '$PLATFORM_GROUP'"
        echo ""
        echo "支持的平台组:"
        echo "  all      - 所有平台"
        echo "  android  - Android 平台"
        echo "  windows  - Windows 平台"
        echo "  linux    - Linux 平台"
        echo "  macos    - macOS 平台"
        exit 1
        ;;
esac

# 构建统计
TOTAL_PLATFORMS=${#PLATFORMS[@]}
SUCCESS_COUNT=0
FAILED_PLATFORMS=()

echo "将构建 $TOTAL_PLATFORMS 个平台: ${PLATFORMS[*]}"
echo ""

# 逐个构建平台
for platform in "${PLATFORMS[@]}"; do
    echo "[$((SUCCESS_COUNT + 1))/$TOTAL_PLATFORMS] 构建 $platform..."
    
    if "$SCRIPT_DIR/build-platform.sh" "$platform" "$BUILD_TYPE"; then
        echo "✓ $platform 构建成功"
        ((SUCCESS_COUNT++))
    else
        echo "✗ $platform 构建失败"
        FAILED_PLATFORMS+=("$platform")
    fi
    echo ""
done

# 输出构建结果
echo "===================="
echo "构建结果汇总:"
echo "成功: $SUCCESS_COUNT/$TOTAL_PLATFORMS"

if [[ ${#FAILED_PLATFORMS[@]} -gt 0 ]]; then
    echo "失败的平台: ${FAILED_PLATFORMS[*]}"
    exit 1
else
    echo "所有平台构建成功!"
fi