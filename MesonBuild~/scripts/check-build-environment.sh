#!/bin/bash

# Unity SQLCipher 构建环境检查工具
# 支持模块化检查和参数化控制

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_CHECKS_DIR="$SCRIPT_DIR/env-checks"

# 导入公共函数
source "$ENV_CHECKS_DIR/functions.sh"

# 向后兼容：如果模块文件为空或不存在，则回退到原脚本
if [[ ! -s "$ENV_CHECKS_DIR/check-env-common.sh" ]]; then
    echo "检测到模块文件为空，回退到原脚本..."

    # 设置参数并调用原脚本
    args=()
    auto_install=false

    # 解析参数
    for arg in "$@"; do
        if [[ "$arg" == "--auto-accept" ]]; then
            auto_install=true
        else
            args+=("$arg")
        fi
    done

    # 设置环境变量
    if [[ "$auto_install" == "true" ]]; then
        export AUTO_INSTALL=true
        export CI=true
        args+=("--auto-install")
    fi

    # 调用原脚本
    exec "$SCRIPT_DIR/check-env.sh" "${args[@]}"
fi

# 如果模块文件存在且不为空，则使用新的模块化方式
source "$ENV_CHECKS_DIR/check-env-common.sh"
source "$ENV_CHECKS_DIR/check-env-macos.sh"
source "$ENV_CHECKS_DIR/check-env-linux.sh"
source "$ENV_CHECKS_DIR/check-env-android.sh"
source "$ENV_CHECKS_DIR/check-env-openharmony.sh"

# 显示帮助信息
show_help() {
    echo "Unity SQLCipher 构建环境检查工具"
    echo ""
    echo "用法: $0 [平台] [选项]"
    echo ""
    echo "支持的平台:"
    echo "  all                    - 检查所有平台 (默认)"
    echo "  common                 - 只检查通用工具 (meson, ninja, openssl)"
    echo "  linux                  - Linux 本地构建环境"
    echo "  linux-docker           - Linux Docker 构建环境"
    echo "  windows                - Windows 交叉编译环境"
    echo "  windows-docker         - Windows Docker 构建环境"
    echo "  android                - Android 构建环境"
    echo "  android-docker         - Android Docker 构建环境"
    echo "  macos                  - macOS 本地构建环境"
    echo "  ios                    - iOS 构建环境"
    echo "  openharmony            - OpenHarmony 构建环境"
    echo ""
    echo "选项:"
    echo "  -h, --help             - 显示此帮助信息"
    echo "  --auto-accept          - 自动接受所有安装提示"
    echo ""
    echo "示例:"
    echo "  $0                     # 检查所有平台"
    echo "  $0 common              # 只检查通用工具"
    echo "  $0 linux-docker        # 只检查Linux Docker环境"
    echo "  $0 android --auto-accept # 自动安装Android环境"
    echo ""
    echo "CI使用示例:"
    echo "  ./check-build-environment.sh linux-docker --auto-accept"
    echo "  ./check-build-environment.sh windows-docker --auto-accept"
    echo "  ./check-build-environment.sh android-docker --auto-accept"
    echo "  ./check-build-environment.sh macos --auto-accept"
    echo "  ./check-build-environment.sh openharmony --auto-accept"
}

# Docker环境检查（只检查OpenSSL）
check_docker_env() {
    local platform="$1"
    print_info "检查 $platform 构建环境..."
    check_meson_subprojects
}

# 输出检查结果
show_results() {
    echo ""
    echo "========================================"
    echo "环境检查结果汇总:"
    echo "========================================"
    print_info "总检查项目: $TOTAL_CHECKS"
    print_success "通过检查: $PASSED_CHECKS"
    
    if [[ ${#FAILED_CHECKS[@]} -gt 0 ]]; then
        print_error "失败检查: ${#FAILED_CHECKS[@]}"
        echo "失败项目:"
        for item in "${FAILED_CHECKS[@]}"; do
            echo "  - $item"
        done
    fi
    
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        print_warning "警告项目: ${#WARNINGS[@]}"
        echo "警告项目:"
        for item in "${WARNINGS[@]}"; do
            echo "  - $item"
        done
    fi
    
    echo ""
    
    if [[ ${#FAILED_CHECKS[@]} -eq 0 ]]; then
        print_success "环境检查通过！"
        echo ""
        print_info "你现在可以运行构建脚本:"
        echo "  ./build-all.sh"
        echo "  ./build-platform.sh <platform> [debug|release]"
        exit 0
    else
        print_error "环境检查未完全通过，请安装缺失的工具"
        echo ""
        print_info "重新运行: $0 $platform --auto-accept"
        exit 1
    fi
}

# 主函数
main() {
    local platform="all"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --auto-accept)
                export AUTO_ACCEPT=true
                ;;
            all|common|linux|linux-docker|windows|windows-docker|android|android-docker|macos|ios|openharmony|openharmony-docker)
                platform="$1"
                ;;
            *)
                echo "未知参数: $1"
                echo "使用 $0 --help 查看帮助"
                exit 1
                ;;
        esac
        shift
    done
    
    # 检测操作系统
    OS=$(detect_os)
    
    echo "========================================"
    echo "Unity SQLCipher 构建环境检查"
    echo "========================================"
    print_info "检测到操作系统: $OS"
    print_info "检查平台: $platform"
    if [[ "$AUTO_ACCEPT" == "true" ]]; then
        print_info "自动安装模式: 启用"
    fi
    echo ""
    
    # 根据平台执行相应的检查
    case "$platform" in
        "all")
            check_common_tools
            if [[ "$OS" == "linux" ]]; then
                check_linux_specific
                check_windows_specific
                check_android_specific
            elif [[ "$OS" == "macos" ]]; then
                check_macos_specific
                check_ios_specific
                check_windows_specific
                check_android_specific
            fi
            check_openharmony_specific
            ;;
        "common")
            check_common_tools
            ;;
        "linux")
            check_common_tools
            check_linux_specific
            ;;
        "linux-docker")
            check_docker_env "Linux Docker"
            ;;
        "windows")
            check_common_tools
            check_windows_specific
            ;;
        "windows-docker")
            check_docker_env "Windows Docker"
            ;;
        "android")
            check_common_tools
            check_android_specific
            ;;
        "android-docker")
            check_docker_env "Android Docker"
            ;;
        "macos")
            check_common_tools
            check_macos_specific
            ;;
        "ios")
            check_common_tools
            check_ios_specific
            ;;
        "openharmony")
            check_common_tools
            check_openharmony_specific
            ;;
    esac
    
    show_results
}

# 脚本入口 - 只有直接运行脚本时才执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
