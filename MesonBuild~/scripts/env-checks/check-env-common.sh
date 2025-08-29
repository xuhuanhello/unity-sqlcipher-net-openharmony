#!/bin/bash

# 通用工具检查模块
# 检查所有平台都需要的基础工具：meson, ninja, openssl

# 导入公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

# 检查通用构建工具
check_common_tools() {
    print_info "检查通用构建工具..."

    # 根据操作系统设置 meson 和 ninja 安装命令
    if [[ "$OS" == "macos" ]]; then
        check_command "meson" "Meson 构建系统" "brew install meson" true
        check_command "ninja" "Ninja 构建工具" "brew install ninja" true
    else
        check_command "meson" "Meson 构建系统" "pip3 install --break-system-packages meson" true
        check_command "ninja" "Ninja 构建工具" "sudo apt-get install -y ninja-build" true
    fi

    # 检查 Meson 子项目依赖 (OpenSSL)
    print_info "检查 Meson 子项目依赖..."
    check_meson_subprojects
}

# 检查Meson子项目依赖 (OpenSSL)
check_meson_subprojects() {
    print_info "检查 OpenSSL wrap 配置..."
    
    # 获取脚本所在目录，然后找到MesonBuild~根目录
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    meson_build_dir="$(dirname "$(dirname "$script_dir")")"
    subprojects_dir="$meson_build_dir/subprojects"
    openssl_wrap_file="$subprojects_dir/openssl.wrap"
    
    # 确保 subprojects 目录存在
    if [[ ! -d "$subprojects_dir" ]]; then
        print_info "创建 subprojects 目录: $subprojects_dir"
        mkdir -p "$subprojects_dir"
        if [[ $? -eq 0 ]]; then
            print_success "subprojects 目录创建成功"
        else
            print_error "subprojects 目录创建失败"
            FAILED_CHECKS+=("subprojects 目录")
            return 1
        fi
    fi
    
    if [[ -f "$openssl_wrap_file" ]]; then
        openssl_version=$(grep 'wrapdb_version' "$openssl_wrap_file" | cut -d'=' -f2 | tr -d ' ')
        print_success "OpenSSL wrap 配置已存在: v$openssl_version"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        
        # 检查是否已下载
        openssl_subproject_dir="$meson_build_dir/subprojects/openssl-3.0.8"
        if [[ -d "$openssl_subproject_dir" ]]; then
            print_success "OpenSSL 子项目已下载"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            print_info "OpenSSL 子项目尚未下载，首次构建时会自动下载"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    else
        print_error "缺少 OpenSSL wrap 配置文件"
        
        echo ""
        print_info "OpenSSL wrap 配置文件不存在，需要安装依赖"
        print_info "将在MesonBuild~目录安装: $meson_build_dir"
        echo ""
        
        # 检查是否自动接受安装
        if [[ "$AUTO_ACCEPT" == "true" ]]; then
            print_info "自动安装模式: 强制安装 OpenSSL wrap..."
            if install_openssl_wrap_force "$meson_build_dir"; then
                # 安装成功，移除失败标记
                print_success "OpenSSL wrap 安装成功"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                # 即使安装失败，也标记为通过，因为构建时会自动处理
                print_warning "OpenSSL wrap 安装可能失败，但构建时会自动处理"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            fi
        elif ask_install "OpenSSL wrap 配置" "cd $meson_build_dir && meson wrap install openssl && meson subprojects download"; then
            print_info "正在安装 OpenSSL wrap..."
            
            # 执行安装命令并捕获输出
            install_output=$(cd "$meson_build_dir" && meson wrap install openssl 2>&1)
            install_result=$?
            
            # 检查是否成功安装或文件已存在
            if [[ $install_result -eq 0 ]] || echo "$install_output" | grep -q "Wrap file already exists"; then
                if echo "$install_output" | grep -q "Wrap file already exists"; then
                    print_success "OpenSSL wrap 已存在，无需重新安装"
                else
                    print_success "OpenSSL wrap 安装完成"
                fi
                
                print_info "正在下载 OpenSSL 子项目..."
                if (cd "$meson_build_dir" && meson subprojects download openssl); then
                    print_success "OpenSSL 子项目下载完成"
                    PASSED_CHECKS=$((PASSED_CHECKS + 1))
                else
                    print_warning "OpenSSL 子项目下载失败，构建时会自动下载"
                    PASSED_CHECKS=$((PASSED_CHECKS + 1))
                fi
            else
                print_error "OpenSSL wrap 安装失败"
                print_error "错误信息: $install_output"
                print_info "请手动运行: cd $meson_build_dir && meson wrap install openssl"
            fi
        else
            # 用户拒绝安装
            FAILED_CHECKS+=("OpenSSL wrap 配置")
        fi
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 2))
}
