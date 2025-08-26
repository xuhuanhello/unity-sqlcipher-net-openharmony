#!/bin/bash

# 构建单个平台的脚本
# 用法: ./build-platform.sh <platform> [debug|release] [additional-meson-options...]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

PLATFORM="$1"
BUILD_TYPE="${2:-release}"

# 从第3个参数开始的所有参数都作为额外的 meson 选项
shift 2 2>/dev/null || true
EXTRA_MESON_OPTIONS="$@"

if [[ -z "$PLATFORM" ]]; then
    echo "用法: $0 <platform> [debug|release] [additional-meson-options...]"
    echo ""
    echo "支持的平台:"
    echo "  windows-x86_64        - Windows 64位"
    echo "  windows-x86           - Windows 32位"
    echo "  windows-arm64         - Windows ARM64"
    echo "  linux-x86_64          - Linux 64位"
    echo "  macos-universal       - macOS 通用二进制"
    echo "  ios-arm64             - iOS 设备 (ARM64)"
    echo "  ios-simulator-arm64   - iOS 模拟器 (ARM64)"
    echo "  ios-simulator-x86_64  - iOS 模拟器 (x86_64)"
    echo "  android-arm64         - Android ARM64"
    echo "  android-arm32         - Android ARM32"
    echo "  android-x86_64        - Android x86_64"
    echo "  android-x86           - Android x86"
    echo ""
    echo "示例:"
    echo "  $0 linux-x86_64 release                       # 标准构建"
    echo "  $0 android-arm64 debug                        # Android ARM64 调试版"
    echo "  $0 ios-arm64 release                          # iOS 设备版"
    echo "  $0 ios-simulator-arm64 debug                  # iOS 模拟器版"
    echo "  $0 windows-x86_64 release                     # Windows 64位版"
    echo ""
    echo "注意："
    echo "  SQLCipher 配置现在统一在 ../Plugins/sqlite-amalgamation/sqlite3_defines.h 中管理"
    echo "  如需修改临时存储模式等配置，请直接编辑该头文件"
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
    PLATFORM_OPTIONS="$ANDROID_OPTIONS"
else
    PLATFORM_OPTIONS=""
fi

# 检查 iOS 平台
if [[ "$PLATFORM" == ios-* ]]; then
    # 设置 iOS SDK 类型
    case "$PLATFORM" in
        ios-arm64)              IOS_SDK="iphoneos" ;;
        ios-simulator-arm64)    IOS_SDK="iphonesimulator" ;;
        ios-simulator-x86_64)   IOS_SDK="iphonesimulator" ;;
    esac
    
    IOS_OPTIONS="-Dios_sdk=$IOS_SDK -Dios_deployment_target=12.0"
    PLATFORM_OPTIONS="$IOS_OPTIONS"
fi

if [[ -n "$EXTRA_MESON_OPTIONS" ]]; then
    echo "开始构建 $PLATFORM ($BUILD_TYPE 模式，额外选项: $EXTRA_MESON_OPTIONS)..."
else
    echo "开始构建 $PLATFORM ($BUILD_TYPE 模式)..."
fi

# 配置构建
cd "$PROJECT_ROOT"
meson setup "$BUILD_DIR" \
    --cross-file="$CROSS_FILE" \
    $BUILD_TYPE_OPTION \
    $PLATFORM_OPTIONS \
    $EXTRA_MESON_OPTIONS

# 构建
meson compile -C "$BUILD_DIR"

# 清理临时文件
if [[ "$PLATFORM" == android-* && -f "$TEMP_CROSS_FILE" ]]; then
    rm -f "$TEMP_CROSS_FILE"
fi

echo "构建完成: $PLATFORM"

# 构建后可选清理（批量构建时跳过）
if [[ -d "$BUILD_DIR" && -z "$BATCH_BUILD" ]]; then
    # 计算构建目录大小
    if command -v du >/dev/null; then
        BUILD_SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "未知")
        echo ""
        echo "💾 构建目录大小: $BUILD_SIZE ($BUILD_DIR)"
        
        # 对于大型构建目录（如iOS），特别提示
        BUILD_SIZE_MB=$(du -sm "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "0")
        if [[ $BUILD_SIZE_MB -gt 20 ]]; then
            echo "💡 提示: 构建目录较大，建议构建完成后清理以节省空间"
        fi
    else
        echo ""
        echo "💾 构建目录: $BUILD_DIR"
    fi
    
    echo ""
    read -p "🧹 是否清理构建目录以节省磁盘空间? [y/N] " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  正在清理构建目录..."
        
        # 检查清理脚本是否存在
        CLEAN_SCRIPT="$SCRIPT_DIR/clean-builds.sh"
        if [[ -f "$CLEAN_SCRIPT" ]]; then
            # 使用专门的清理脚本（非交互模式）
            echo "  删除目录: $BUILD_DIR"
            rm -rf "$BUILD_DIR"
            
            # 清理对应的 .meta 文件
            META_FILE="$BUILD_DIR.meta"
            if [[ -f "$META_FILE" ]]; then
                echo "  删除文件: $META_FILE"
                rm -f "$META_FILE"
            fi
            
            echo "✅ 清理完成! 已释放 $BUILD_SIZE 空间"
        else
            # 回退到简单清理
            echo "  删除目录: $BUILD_DIR"
            rm -rf "$BUILD_DIR"
            echo "✅ 清理完成!"
        fi
        
        # iOS特殊提示
        if [[ "$PLATFORM" == ios-* ]]; then
            echo "💡 iOS静态库已保留在: ../Plugins/lib/ios*/libgilzoide-sqlite-net.a"
            echo "💡 该静态库可直接用于Unity的DllImport，包含自包含的OpenSSL"
        fi
    else
        echo "ℹ️  构建目录已保留，可稍后使用 ./scripts/clean-builds.sh $PLATFORM 清理"
    fi
elif [[ -d "$BUILD_DIR" && -n "$BATCH_BUILD" ]]; then
    # 批量构建模式的简要提示
    if command -v du >/dev/null; then
        BUILD_SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "未知")
        echo "💾 构建目录: $BUILD_DIR ($BUILD_SIZE) - 将在批量构建完成后统一处理"
    fi
fi