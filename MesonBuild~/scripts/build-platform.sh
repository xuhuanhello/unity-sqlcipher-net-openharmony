#!/bin/bash

# 构建单个平台的脚本
# 用法: ./build-platform.sh <platform> [debug|release] [additional-meson-options...]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 智能检测项目根目录
if [[ -f "$SCRIPT_DIR/../cross-files/$1.ini" ]]; then
    # 当前在MesonBuild~目录中（Docker环境或本地MesonBuild~目录）
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
elif [[ -f "$SCRIPT_DIR/../../MesonBuild~/cross-files/$1.ini" ]]; then
    # 正常的项目结构
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
else
    # 回退到原始逻辑
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
fi

PLATFORM="$1"
BUILD_TYPE="${2:-release}"

# 从第3个参数开始的所有参数都作为额外的 meson 选项
if [[ $# -gt 2 ]]; then
    shift 2
    EXTRA_MESON_OPTIONS="$@"
else
    EXTRA_MESON_OPTIONS=""
fi

# 检查是否是Docker构建
USE_DOCKER=false
DOCKER_PLATFORM=""
if [[ "$PLATFORM" == *-docker ]]; then
    USE_DOCKER=true
    # 移除 -docker 后缀得到实际平台名
    DOCKER_PLATFORM="${PLATFORM%-docker}"
    PLATFORM="$DOCKER_PLATFORM"
fi

if [[ -z "$PLATFORM" || "$PLATFORM" == "-h" || "$PLATFORM" == "--help" ]]; then
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
    echo "  harmony-arm64         - HarmonyOS ARM64"
    echo ""
    echo "Docker构建平台 (添加 -docker 后缀):"
    echo "  windows-x86_64-docker        - Windows 64位 (Docker)"
    echo "  windows-x86-docker           - Windows 32位 (Docker)"
    echo "  windows-arm64-docker         - Windows ARM64 (Docker)"
    echo "  linux-x86_64-docker          - Linux 64位 (Docker)"
    echo "  android-arm64-docker         - Android ARM64 (Docker)"
    echo "  android-arm32-docker         - Android ARM32 (Docker)"
    echo "  android-x86_64-docker        - Android x86_64 (Docker)"
    echo "  android-x86-docker           - Android x86 (Docker)"
    echo ""
    echo "示例:"
    echo "  $0 linux-x86_64 release                       # 标准构建"
    echo "  $0 android-arm64 debug                        # Android ARM64 调试版"
    echo "  $0 ios-arm64 release                          # iOS 设备版"
    echo "  $0 ios-simulator-arm64 debug                  # iOS 模拟器版"
    echo "  $0 windows-x86_64 release                     # Windows 64位版"
    echo "  $0 windows-x86_64-docker release              # Windows 64位版 (Docker)"
    echo "  $0 linux-x86_64-docker debug                  # Linux 64位版 (Docker)"
    echo "  $0 android-arm64-docker release               # Android ARM64版 (Docker)"
    echo ""
    echo "注意："
    echo "  SQLCipher 配置现在统一在 ../Plugins/sqlite-amalgamation/sqlite3_defines.h 中管理"
    echo "  如需修改临时存储模式等配置，请直接编辑该头文件"
    exit 1
fi

# Docker构建函数
build_with_docker() {
    local platform="$1"
    local build_type="$2"
    local extra_options="$3"
    
    # 检查Docker是否可用
    if ! command -v docker &> /dev/null; then
        echo "错误: Docker 未安装或不可用"
        echo "请先安装 Docker 或使用标准构建方式"
        exit 1
    fi
    
    # 检查Docker是否运行
    if ! docker info &> /dev/null; then
        echo "错误: Docker 服务未运行"
        echo "请启动 Docker 服务"
        exit 1
    fi
    
    # 确定 Dockerfile 和镜像名称
    local dockerfile_name=""
    local image_name="sqlcipher-build"
    
    case "$platform" in
        android-*)
            dockerfile_name="Dockerfile.android"
            image_name="sqlcipher-build-android"
            ;;
        windows-arm64*)
            # 首先尝试使用预装meson的本地镜像，如果不存在则使用外部镜像
            local custom_image="unity-sqlcipher-windows-arm64:latest"
            if docker image inspect "$custom_image" >/dev/null 2>&1; then
                image_name="$custom_image"
                use_external_image=false
                use_custom_image=true
                echo "使用预装meson的本地镜像: $custom_image"
            else
                echo "本地镜像不存在，使用外部镜像: mstorsjo/llvm-mingw:latest"
                echo "💡 提示: 可以构建本地镜像以加速后续构建:"
                echo "   docker build -f Dockerfiles/Dockerfile.windows-arm64-meson -t $custom_image ."
                image_name="mstorsjo/llvm-mingw:latest"
                use_external_image=true
                use_custom_image=false
            fi
            ;;
        windows-*)
            dockerfile_name="Dockerfile.windows"
            image_name="sqlcipher-build-windows"
            ;;
        linux-*)
            dockerfile_name="Dockerfile.linux"
            image_name="sqlcipher-build-linux"
            ;;
        *)
            echo "错误: 平台 $platform 不支持 Docker 构建"
            echo "支持的 Docker 构建平台: android-*, windows-*, linux-*"
            exit 1
            ;;
    esac
    
    # 只有非外部镜像且非自定义镜像才需要检查 Dockerfile
    if [ "${use_external_image:-false}" != "true" ] && [ "${use_custom_image:-false}" != "true" ]; then
        local dockerfile_path="$PROJECT_ROOT/MesonBuild~/Dockerfiles/$dockerfile_name"
        
        if [[ ! -f "$dockerfile_path" ]]; then
            echo "错误: 找不到 Dockerfile: $dockerfile_path"
            exit 1
        fi
    fi
    
    echo "使用 Docker 构建 $platform ($build_type 模式)..."
    
    # 构建或拉取 Docker 镜像
    if [ "${use_external_image:-false}" = "true" ]; then
        echo "拉取外部 Docker 镜像: $image_name"
        if ! docker pull "$image_name"; then
            echo "错误: Docker 镜像拉取失败"
            exit 1
        fi
    elif [ "${use_custom_image:-false}" = "true" ]; then
        echo "使用已存在的自定义镜像: $image_name"
    else
        local dockerfile_path="$PROJECT_ROOT/MesonBuild~/Dockerfiles/$dockerfile_name"
        echo "构建 Docker 镜像: $image_name"
        
        # Android构建需要使用amd64平台以确保NDK工具链正常工作
        local docker_build_args=""
        if [[ "$platform" == android-* ]]; then
            docker_build_args="--platform=linux/amd64"
        fi
        
        if ! docker build $docker_build_args -f "$dockerfile_path" -t "$image_name:latest" "$PROJECT_ROOT"; then
            echo "错误: Docker 镜像构建失败"
            exit 1
        fi
        # 为自建镜像添加:latest标签以保持一致性
        image_name="$image_name:latest"
    fi
    
    # 在 Docker 容器中运行构建
    echo "在 Docker 容器中执行构建..."
    
    # 创建容器运行命令
    local docker_cmd="docker run --rm"
    docker_cmd="$docker_cmd -v \"$PROJECT_ROOT:/workspace\""
    docker_cmd="$docker_cmd -w /workspace/MesonBuild~"
    
    # 对于 Android 平台，需要设置 ANDROID_NDK_ROOT 并使用amd64平台
    if [[ "$platform" == android-* ]]; then
        docker_cmd="$docker_cmd --platform=linux/amd64"
        docker_cmd="$docker_cmd -e ANDROID_NDK_ROOT=/opt/ndk"
    fi
    
    docker_cmd="$docker_cmd $image_name"
    
    # 根据镜像类型设置不同的命令
    if [ "${use_external_image:-false}" = "true" ]; then
        # 外部镜像需要安装依赖
        docker_cmd="$docker_cmd bash -c 'export BATCH_BUILD=1 && apt-get update -qq && apt-get install -y python3-pip && pip3 install --break-system-packages meson && ./scripts/build-platform.sh $platform $build_type $extra_options; exit \$?'"
    elif [ "${use_custom_image:-false}" = "true" ]; then
        # 自定义镜像已预装依赖，直接构建
        docker_cmd="$docker_cmd bash -c 'export BATCH_BUILD=1 && ./scripts/build-platform.sh $platform $build_type $extra_options'"
    else
        # 标准镜像
        if [[ -n "$extra_options" ]]; then
            docker_cmd="$docker_cmd bash -c 'export BATCH_BUILD=1 && ./scripts/build-platform.sh $platform $build_type $extra_options'"
        else
            docker_cmd="$docker_cmd bash -c 'export BATCH_BUILD=1 && ./scripts/build-platform.sh $platform $build_type'"
        fi
    fi
    
    echo "执行命令: $docker_cmd"
    
    # 执行 Docker 构建
    if eval "$docker_cmd"; then
        echo "Docker 构建成功: $platform"
        
        # Docker构建完成后提供清理选项
        echo ""
        echo "📁 Docker构建完成，现在可以选择是否清理构建目录："
        
        # 检查构建目录大小
        BUILD_DIR="$PROJECT_ROOT/MesonBuild~/build-$platform"
        if [[ -d "$BUILD_DIR" ]] && command -v du >/dev/null; then
            BUILD_SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "未知")
            BUILD_SIZE_MB=$(du -sm "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "0")
            echo "💾 构建目录大小: $BUILD_SIZE ($BUILD_DIR)"
            
            if [[ $BUILD_SIZE_MB -gt 20 ]]; then
                echo "💡 提示: 构建目录较大，建议清理以节省空间"
            fi
            
            echo ""
            read -p "🧹 是否清理构建目录? [y/N] " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "🗑️  正在清理构建目录..."
                rm -rf "$BUILD_DIR"
                
                # 清理对应的 .meta 文件
                META_FILE="$BUILD_DIR.meta"
                if [[ -f "$META_FILE" ]]; then
                    echo "  删除文件: $META_FILE"
                    rm -f "$META_FILE"
                fi
                
                echo "✅ 清理完成! 已释放 $BUILD_SIZE 空间"
            else
                echo "⏭️  跳过清理，构建目录已保留"
                echo "💡 稍后可使用以下命令清理: rm -rf \"$BUILD_DIR\""
            fi
        fi
    else
        echo "错误: Docker 构建失败: $platform"
        exit 1
    fi
    
    return 0
}

# 如果是Docker构建，直接调用Docker构建函数
if [[ "$USE_DOCKER" == "true" ]]; then
    # 对于 Docker 构建，传递真正的额外 meson 选项（不包括平台名称）
    build_with_docker "$PLATFORM" "$BUILD_TYPE" "$EXTRA_MESON_OPTIONS"
    exit 0
fi

# 检查交叉编译文件是否存在
# 根据PROJECT_ROOT的结构确定正确的路径
if [[ -f "$PROJECT_ROOT/cross-files/$PLATFORM.ini" ]]; then
    CROSS_FILE="$PROJECT_ROOT/cross-files/$PLATFORM.ini"
elif [[ -f "$PROJECT_ROOT/MesonBuild~/cross-files/$PLATFORM.ini" ]]; then
    CROSS_FILE="$PROJECT_ROOT/MesonBuild~/cross-files/$PLATFORM.ini"
else
    echo "错误: 找不到交叉编译文件"
    echo "尝试的路径:"
    echo "  $PROJECT_ROOT/cross-files/$PLATFORM.ini"
    echo "  $PROJECT_ROOT/MesonBuild~/cross-files/$PLATFORM.ini"
    exit 1
fi

# 设置构建目录
if [[ -d "$PROJECT_ROOT/cross-files" ]]; then
    # 当前在MesonBuild~目录中
    BUILD_DIR="$PROJECT_ROOT/build-$PLATFORM"
else
    # 正常的项目结构
    BUILD_DIR="$PROJECT_ROOT/MesonBuild~/build-$PLATFORM"
fi

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

# 检查 HarmonyOS NDK (如果构建 HarmonyOS 平台)
if [[ "$PLATFORM" == harmony-* ]]; then
    if [[ -z "$OHOS_NDK_ROOT" ]]; then
        echo "错误: 构建 HarmonyOS 平台需要设置 OHOS_NDK_ROOT 环境变量"
        echo "请从以下地址下载 HarmonyOS SDK:"
        echo "https://repo.huaweicloud.com/openharmony/os/5.1.0-Release/L2-SDK-MAC-M1-PUBLIC.tar.gz"
        exit 1
    fi
    
    # 替换交叉编译文件中的环境变量
    TEMP_CROSS_FILE="/tmp/harmony-cross-$PLATFORM.ini"
    sed "s|\$OHOS_NDK_ROOT|$OHOS_NDK_ROOT|g" "$CROSS_FILE" > "$TEMP_CROSS_FILE"
    CROSS_FILE="$TEMP_CROSS_FILE"
    
    # 设置 HarmonyOS ABI 和 STL
    case "$PLATFORM" in
        harmony-arm64)   HARMONY_ABI="arm64-v8a" ;;
    esac
    
    # 默认使用 c++_shared STL (对应官方 CMake 示例中的 OHOS_STL=c++_shared)
    HARMONY_STL="c++_shared"
    
    # 自动修复 OpenSSL 子项目对 HarmonyOS 的支持
    echo "🔧 正在修复 OpenSSL 子项目对 HarmonyOS 的支持..."
    OPENSSL_MESON_FILE="subprojects/openssl-3.0.8/meson.build"
    if [[ -f "$OPENSSL_MESON_FILE" ]]; then
        # 检查是否已经包含 harmony 支持
        if ! grep -q "is_linux = host_machine.system() in \['linux', 'android', 'harmony'\]" "$OPENSSL_MESON_FILE"; then
            # 备份原文件
            cp "$OPENSSL_MESON_FILE" "$OPENSSL_MESON_FILE.backup"
            echo "📄 已备份原始文件: $OPENSSL_MESON_FILE.backup"
            
            # 应用修复
            sed -i.tmp "s/is_linux = host_machine.system() in \['linux', 'android'\]/is_linux = host_machine.system() in ['linux', 'android', 'harmony']/" "$OPENSSL_MESON_FILE"
            rm -f "$OPENSSL_MESON_FILE.tmp"
            
            echo "✅ OpenSSL 子项目已修复，现在支持 HarmonyOS"
        else
            echo "✅ OpenSSL 子项目已经支持 HarmonyOS，无需修复"
        fi
    else
        echo "⚠️  OpenSSL 子项目文件不存在: $OPENSSL_MESON_FILE"
        echo "   这可能是首次构建，Meson 会自动下载子项目"
    fi
    
    HARMONY_OPTIONS="-Dharmony_build=true -Dharmony_abi=$HARMONY_ABI -Dharmony_stl=$HARMONY_STL"
    PLATFORM_OPTIONS="$HARMONY_OPTIONS"
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
# 确定正确的meson.build文件位置
if [[ -f "$PROJECT_ROOT/meson.build" ]]; then
    # 当前在MesonBuild~目录中
    cd "$PROJECT_ROOT"
else
    # 正常的项目结构
    cd "$PROJECT_ROOT/MesonBuild~"
fi

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

if [[ "$PLATFORM" == harmony-* && -f "$TEMP_CROSS_FILE" ]]; then
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
    
    # Docker构建时不进行交互，将清理信息保存供后续处理
    if [[ -n "$BATCH_BUILD" || -f /.dockerenv ]]; then
        echo "ℹ️  Docker构建完成，清理选项将在容器外提供"
        # 保存构建信息供Docker构建完成后使用
        BUILD_INFO_FILE="/tmp/build_cleanup_info_${platform}.txt"
        echo "BUILD_DIR=$BUILD_DIR" > "$BUILD_INFO_FILE"
        echo "BUILD_SIZE_MB=$BUILD_SIZE_MB" >> "$BUILD_INFO_FILE"
        echo "PLATFORM=$platform" >> "$BUILD_INFO_FILE"
    else
        # 本地构建时保持交互
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
            echo "⏭️  跳过清理，构建目录已保留"
        fi
    fi
elif [[ -d "$BUILD_DIR" && -n "$BATCH_BUILD" ]]; then
    # 批量构建模式的简要提示
    if command -v du >/dev/null; then
        BUILD_SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "未知")
        echo "💾 构建目录: $BUILD_DIR ($BUILD_SIZE) - 将在批量构建完成后统一处理"
    fi
fi