#!/bin/bash

# 构建所有平台的脚本
# 用法: ./build-all.sh [platform-group] [debug|release]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLATFORM_GROUP="${1:-all}"
BUILD_TYPE="${2:-release}"

# 显示用法信息
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "构建所有平台的脚本"
    echo ""
    echo "用法: $0 [platform-group] [debug|release]"
    echo ""
    echo "参数:"
    echo "  platform-group  要构建的平台组 (默认: all)"
    echo "  debug|release   构建类型 (默认: release)"
    echo ""
    echo "支持的平台组:"
    echo "  all         - 所有平台"
    echo "  android     - Android 平台"
    echo "  windows     - Windows 平台"
    echo "  linux       - Linux 平台"
    echo "  macos       - macOS 平台"
    echo "  ios         - iOS 平台"
    echo "  harmony     - HarmonyOS 平台"
    echo ""
    echo "Docker平台组 (需要Docker环境):"
    echo "  all-docker     - 所有支持Docker的平台"
    echo "  android-docker - Android 平台 (Docker)"
    echo "  windows-docker - Windows 平台 (Docker)"
    echo "  linux-docker   - Linux 平台 (Docker)"
    echo ""
    echo "示例:"
    echo "  $0                        # 构建所有平台 (release)"
    echo "  $0 ios                    # 只构建iOS平台 (release)"
    echo "  $0 android debug          # 构建Android平台 (debug)"
    echo "  $0 all release            # 构建所有平台 (release)"
    echo "  $0 android-docker release # 构建Android平台 (Docker)"
    echo "  $0 all-docker debug       # 构建所有Docker平台 (debug)"
    exit 0
fi

echo "开始批量构建 (平台组: $PLATFORM_GROUP, 模式: $BUILD_TYPE)..."

# 定义平台组
ALL_PLATFORMS=(
    "windows-x86_64"
    "windows-x86"
    "windows-arm64"
    "linux-x86_64"
    "macos-universal"
    "ios-arm64"
    "ios-simulator-arm64"
    "ios-simulator-x86_64"
    "android-arm64"
    "android-arm32"
    "android-x86_64"
    "android-x86"
    "harmony-arm64"
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

IOS_PLATFORMS=(
    "ios-arm64"
    "ios-simulator-arm64"
    "ios-simulator-x86_64"
)

HARMONY_PLATFORMS=(
    "harmony-arm64"
)

# Docker平台组
ALL_DOCKER_PLATFORMS=(
    "windows-x86_64-docker"
    "windows-x86-docker"
    "windows-arm64-docker"
    "linux-x86_64-docker"
    "android-arm64-docker"
    "android-arm32-docker"
    "android-x86_64-docker"
    "android-x86-docker"
)

ANDROID_DOCKER_PLATFORMS=(
    "android-arm64-docker"
    "android-arm32-docker"
    "android-x86_64-docker"
    "android-x86-docker"
)

WINDOWS_DOCKER_PLATFORMS=(
    "windows-x86_64-docker"
    "windows-x86-docker"
    "windows-arm64-docker"
)

LINUX_DOCKER_PLATFORMS=(
    "linux-x86_64-docker"
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
    "ios")
        PLATFORMS=("${IOS_PLATFORMS[@]}")
        ;;
    "harmony")
        PLATFORMS=("${HARMONY_PLATFORMS[@]}")
        ;;
    "all-docker")
        PLATFORMS=("${ALL_DOCKER_PLATFORMS[@]}")
        ;;
    "android-docker")
        PLATFORMS=("${ANDROID_DOCKER_PLATFORMS[@]}")
        ;;
    "windows-docker")
        PLATFORMS=("${WINDOWS_DOCKER_PLATFORMS[@]}")
        ;;
    "linux-docker")
        PLATFORMS=("${LINUX_DOCKER_PLATFORMS[@]}")
        ;;
    *)
        echo "错误: 未知的平台组 '$PLATFORM_GROUP'"
        echo ""
        echo "用法: $0 [platform-group] [debug|release]"
        echo ""
        echo "支持的平台组:"
        echo "  all            - 所有平台"
        echo "  android        - Android 平台"
        echo "  windows        - Windows 平台"
        echo "  linux          - Linux 平台"
        echo "  macos          - macOS 平台"
        echo "  ios            - iOS 平台"
        echo "  harmony        - HarmonyOS 平台"
        echo "  all-docker     - 所有Docker平台"
        echo "  android-docker - Android 平台 (Docker)"
        echo "  windows-docker - Windows 平台 (Docker)"
        echo "  linux-docker   - Linux 平台 (Docker)"
        echo ""
        echo "示例: $0 ios release"
        exit 1
        ;;
esac

# 构建统计
TOTAL_PLATFORMS=${#PLATFORMS[@]}
SUCCESS_COUNT=0
FAILED_PLATFORMS=()

# 检查是否包含Docker平台
DOCKER_PLATFORMS_COUNT=0
for platform in "${PLATFORMS[@]}"; do
    if [[ "$platform" == *-docker ]]; then
        DOCKER_PLATFORMS_COUNT=$((DOCKER_PLATFORMS_COUNT + 1))
    fi
done

# 如果包含Docker平台，检查Docker环境
if [[ $DOCKER_PLATFORMS_COUNT -gt 0 ]]; then
    echo "检测到 $DOCKER_PLATFORMS_COUNT 个Docker构建平台，检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        echo "错误: Docker 未安装"
        echo "请先安装 Docker 或使用标准构建方式"
        echo "安装Docker: ./scripts/check-env.sh"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "错误: Docker 服务未运行"
        echo "请启动 Docker 服务"
        exit 1
    fi
    
    echo "✓ Docker 环境检查通过"
    echo ""
fi

echo "将构建 $TOTAL_PLATFORMS 个平台: ${PLATFORMS[*]}"
echo ""

# 逐个构建平台
for platform in "${PLATFORMS[@]}"; do
    echo "[$((SUCCESS_COUNT + 1))/$TOTAL_PLATFORMS] 构建 $platform..."
    echo "DEBUG: 开始构建平台 $platform"
    
    # 使用 set +e 临时允许命令失败，避免整个脚本退出
    set +e
    # 对于批量构建，设置环境变量跳过单个平台的清理询问
    BATCH_BUILD=1 "$SCRIPT_DIR/build-platform.sh" "$platform" "$BUILD_TYPE"
    BUILD_RESULT=$?
    set -e
    
    echo "DEBUG: 平台 $platform 构建结束，退出码: $BUILD_RESULT"
    
    if [[ $BUILD_RESULT -eq 0 ]]; then
        echo "✓ $platform 构建成功"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "✗ $platform 构建失败 (退出码: $BUILD_RESULT)"
        FAILED_PLATFORMS+=("$platform")
    fi
    echo "DEBUG: 当前成功数: $SUCCESS_COUNT, 失败数: ${#FAILED_PLATFORMS[@]}"
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
    
    # 批量构建完成后的清理选项
    echo ""
    echo "🧹 批量构建清理选项"
    echo "=============================="
    
    # 查找所有构建目录并计算总大小
    BUILD_DIRS=()
    TOTAL_SIZE=0
    
    # 切换到项目根目录（包含构建目录的地方）
    cd "$SCRIPT_DIR/.."
    
    for platform in "${PLATFORMS[@]}"; do
        BUILD_DIR="build-$platform"
        if [[ -d "$BUILD_DIR" ]]; then
            BUILD_DIRS+=("$BUILD_DIR")
            if command -v du >/dev/null; then
                size=$(du -sm "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "0")
                TOTAL_SIZE=$((TOTAL_SIZE + size))
                size_human=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "未知")
                echo "  📁 $BUILD_DIR ($size_human)"
            else
                echo "  📁 $BUILD_DIR"
            fi
        fi
    done
    
    if [[ ${#BUILD_DIRS[@]} -gt 0 ]]; then
        echo ""
        if [[ $TOTAL_SIZE -gt 0 ]]; then
            echo "💾 构建目录总大小: ${TOTAL_SIZE}MB"
        fi
        echo "💡 提示: 构建产物已保存到 ../Plugins/lib/ 目录，中间文件可以安全清理"
        echo ""
        
        echo "选择清理选项:"
        echo "  1) 不清理 - 保留所有构建目录"
        echo "  2) 清理所有 - 删除所有构建目录和.meta文件"
        echo "  3) 选择性清理 - 使用交互式清理工具"
        echo ""
        read -p "请选择 [1-3]: " -n 1 -r CLEAN_CHOICE
        echo
        echo
        
        case $CLEAN_CHOICE in
            1)
                echo "ℹ️  构建目录已保留"
                echo "💡 可稍后使用 ./scripts/clean-builds.sh 手动清理"
                ;;
            2)
                echo "🗑️  清理所有构建目录..."
                deleted_count=0
                # 切换回正确的目录进行删除
                cd "$SCRIPT_DIR/.."
                for build_dir in "${BUILD_DIRS[@]}"; do
                    echo "  删除目录: $build_dir"
                    rm -rf "$build_dir"
                    
                    # 清理对应的 .meta 文件
                    meta_file="${build_dir}.meta"
                    if [[ -f "$meta_file" ]]; then
                        echo "  删除文件: $meta_file"
                        rm -f "$meta_file"
                    fi
                    deleted_count=$((deleted_count + 1))
                done
                echo "✅ 清理完成! 删除了 $deleted_count 个构建目录"
                if [[ $TOTAL_SIZE -gt 0 ]]; then
                    echo "💾 释放了约 ${TOTAL_SIZE}MB 空间"
                fi
                ;;
            3)
                echo "🔧 启动交互式清理工具..."
                echo ""
                "$SCRIPT_DIR/clean-builds.sh"
                ;;
            *)
                echo "ℹ️  无效选择，构建目录已保留"
                ;;
        esac
    else
        echo "ℹ️  没有找到需要清理的构建目录"
    fi
fi