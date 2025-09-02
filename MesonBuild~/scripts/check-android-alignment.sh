#!/bin/bash

# Android ELF 16KB 对齐检查脚本
# 基于 Google Play 官方提供的检查脚本
# 用于验证 Android 共享库是否满足 16KB 对齐要求

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 显示使用说明
usage() {
    echo "Android ELF 16KB 对齐检查工具"
    echo ""
    echo "用法: $0 [库文件路径|目录路径]"
    echo ""
    echo "说明:"
    echo "  检查 Android 共享库(.so)的 ELF 对齐情况"
    echo "  库文件需要 16KB 或 64KB 对齐才能在 Android 14+ 上正常工作"
    echo ""
    echo "示例:"
    echo "  $0 /path/to/library.so"
    echo "  $0 /path/to/android/libs/"
    echo ""
}

# 检查单个 ELF 文件的对齐
check_elf_alignment() {
    local file="$1"
    
    # 检查是否是 ELF 文件
    if ! file "$file" | grep -q "ELF"; then
        return 0  # 不是 ELF 文件，跳过
    fi
    
    # 使用 objdump 获取 LOAD 段的对齐信息
    local alignment=$(objdump -p "$file" 2>/dev/null | grep LOAD | awk '{ print $NF }' | head -1)
    
    if [[ -z "$alignment" ]]; then
        print_warning "无法获取 $file 的对齐信息"
        return 1
    fi
    
    # 检查对齐是否满足 16KB (2^14) 或更高
    if [[ $alignment =~ 2\*\*(1[4-9]|[2-9][0-9]|[1-9][0-9]{2,}) ]]; then
        print_success "$(basename "$file"): 对齐正确 ($alignment)"
        return 0
    else
        print_error "$(basename "$file"): 对齐不足 ($alignment) - 需要 16KB 或更高对齐"
        return 1
    fi
}

# 主函数
main() {
    local input="$1"
    
    if [[ -z "$input" ]]; then
        usage
        exit 1
    fi
    
    if [[ "$input" == "--help" || "$input" == "-h" ]]; then
        usage
        exit 0
    fi
    
    if [[ ! -f "$input" && ! -d "$input" ]]; then
        print_error "文件或目录不存在: $input"
        exit 1
    fi
    
    print_info "开始检查 Android ELF 对齐..."
    echo ""
    
    local unaligned_count=0
    local total_count=0
    
    if [[ -f "$input" ]]; then
        # 检查单个文件
        if check_elf_alignment "$input"; then
            total_count=1
        else
            total_count=1
            unaligned_count=1
        fi
    else
        # 检查目录中的所有 .so 文件
        print_info "扫描目录: $input"
        
        while IFS= read -r -d '' file; do
            if check_elf_alignment "$file"; then
                total_count=$((total_count + 1))
            else
                total_count=$((total_count + 1))
                unaligned_count=$((unaligned_count + 1))
            fi
        done < <(find "$input" -name "*.so" -type f -print0)
    fi
    
    echo ""
    print_info "检查结果总结:"
    echo "  总共检查: $total_count 个库文件"
    echo "  对齐正确: $((total_count - unaligned_count)) 个"
    echo "  对齐不足: $unaligned_count 个"
    
    if [[ $unaligned_count -eq 0 ]]; then
        print_success "🎉 所有库文件都满足 16KB 对齐要求！"
        return 0
    else
        print_error "❌ 发现 $unaligned_count 个库文件对齐不足"
        print_info "💡 提示: 对齐不足的库可能在 Android 14+ 设备上无法正常加载"
        return 1
    fi
}

# 执行主函数
main "$@"
