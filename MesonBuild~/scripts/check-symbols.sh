#!/bin/bash

# 符号导出检查脚本
# 用于验证构建产物的符号导出情况，确保：
# 1. cr_前缀的SQLite/SQLCipher符号正确导出
# 2. OpenSSL符号被正确隐藏
# 3. 架构信息正确

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

# 检测运行环境
detect_environment() {
    local env_type="native"

    # 检测Docker环境
    if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        env_type="docker"
    fi

    echo "$env_type"
}

# 检测Windows工具类型
detect_windows_tools() {
    local tool_type="none"

    if command -v x86_64-w64-mingw32-objdump &> /dev/null; then
        local version=$(x86_64-w64-mingw32-objdump --version 2>/dev/null | head -1)
        if echo "$version" | grep -q "LLVM"; then
            tool_type="llvm-mingw-x64"
        else
            tool_type="gnu-mingw-x64"
        fi
    elif command -v i686-w64-mingw32-objdump &> /dev/null; then
        local version=$(i686-w64-mingw32-objdump --version 2>/dev/null | head -1)
        if echo "$version" | grep -q "LLVM"; then
            tool_type="llvm-mingw-x86"
        else
            tool_type="gnu-mingw-x86"
        fi
    elif command -v objdump &> /dev/null; then
        tool_type="native-objdump"
    fi

    echo "$tool_type"
}

# 使用说明
usage() {
    echo "用法: $0 <platform-architecture> [library_file]"
    echo ""
    echo "参数:"
    echo "  platform-architecture - 平台和架构 (如 macos-universal, ios-arm64, linux-x86_64)"
    echo "  library_file         - 可选，指定库文件路径，否则自动查找"
    echo ""
    echo "示例:"
    echo "  $0 macos-universal                    # 自动查找macOS库文件"
    echo "  $0 ios-arm64                          # 自动查找iOS ARM64库文件"
    echo "  $0 linux-x86_64 /path/to/lib.so      # 检查指定的库文件"
    echo ""
    echo "支持的平台:"
    echo "  macos-universal, ios-arm64, ios-simulator-x86_64"
    echo "  linux-x86_64, android-arm64, windows-x86_64"
    echo "  harmony-arm64"
    exit 1
}

# 检查参数
if [[ $# -lt 1 ]]; then
    usage
fi

PLATFORM_ARCH="$1"
LIBRARY_FILE="${2:-}"

# 解析平台和架构
if [[ "$PLATFORM_ARCH" =~ ^([^-]+)-(.+)$ ]]; then
    PLATFORM="${BASH_REMATCH[1]}"
    ARCHITECTURE="${BASH_REMATCH[2]}"
else
    print_error "无效的平台-架构格式: $PLATFORM_ARCH"
    print_error "应该使用格式: platform-architecture (如 macos-universal)"
    exit 1
fi

# 如果没有指定库文件，自动查找
if [[ -z "$LIBRARY_FILE" ]]; then
    print_info "自动查找 $PLATFORM_ARCH 的库文件..."

    # 确定脚本所在目录和项目根目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

    # 根据平台确定可能的库文件位置和文件名模式
    POSSIBLE_PATHS=()
    FILE_PATTERNS=()

    case "$PLATFORM" in
        "macos")
            POSSIBLE_PATHS=(
                "$PROJECT_ROOT/Plugins/lib/macos"
                "/workspace/Plugins/lib/macos"
                "../Plugins/lib/macos"
            )
            FILE_PATTERNS=("*.dylib" "*.a")
            ;;
        "ios")
            if [[ "$ARCHITECTURE" == *"simulator"* ]]; then
                POSSIBLE_PATHS=(
                    "$PROJECT_ROOT/Plugins/lib/ios-simulator"
                    "/workspace/Plugins/lib/ios-simulator"
                    "../Plugins/lib/ios-simulator"
                )
            else
                POSSIBLE_PATHS=(
                    "$PROJECT_ROOT/Plugins/lib/ios"
                    "/workspace/Plugins/lib/ios"
                    "../Plugins/lib/ios"
                )
            fi
            FILE_PATTERNS=("*.a" "*.dylib")
            ;;
        "windows")
            POSSIBLE_PATHS=(
                "$PROJECT_ROOT/Plugins/lib/windows/$ARCHITECTURE"
                "/workspace/Plugins/lib/windows/$ARCHITECTURE"
                "../Plugins/lib/windows/$ARCHITECTURE"
            )
            FILE_PATTERNS=("*.dll")
            ;;
        "linux")
            POSSIBLE_PATHS=(
                "$PROJECT_ROOT/Plugins/lib/linux/$ARCHITECTURE"
                "/workspace/Plugins/lib/linux/$ARCHITECTURE"
                "../Plugins/lib/linux/$ARCHITECTURE"
            )
            FILE_PATTERNS=("*.so")
            ;;
        "android")
            POSSIBLE_PATHS=(
                "$PROJECT_ROOT/Plugins/lib/android/$ARCHITECTURE"
                "/workspace/Plugins/lib/android/$ARCHITECTURE"
                "../Plugins/lib/android/$ARCHITECTURE"
            )
            FILE_PATTERNS=("*.so")
            ;;
        "harmony")
            POSSIBLE_PATHS=(
                "$PROJECT_ROOT/Plugins/lib/OpenHarmony/$ARCHITECTURE"
                "/workspace/Plugins/lib/OpenHarmony/$ARCHITECTURE"
                "../Plugins/lib/OpenHarmony/$ARCHITECTURE"
            )
            FILE_PATTERNS=("*.so")
            ;;
        *)
            print_error "不支持的平台: $PLATFORM"
            exit 1
            ;;
    esac

    # 在可能的路径中查找库文件
    FOUND_FILES=()
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            for pattern in "${FILE_PATTERNS[@]}"; do
                while IFS= read -r -d '' file; do
                    FOUND_FILES+=("$file")
                done < <(find "$path" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
            done

            if [[ ${#FOUND_FILES[@]} -gt 0 ]]; then
                break
            fi
        fi
    done

    if [[ ${#FOUND_FILES[@]} -eq 0 ]]; then
        print_error "未找到 $PLATFORM_ARCH 的库文件"
        print_error "查找的路径:"
        for path in "${POSSIBLE_PATHS[@]}"; do
            print_error "  $path"
        done
        print_error "查找的文件模式: ${FILE_PATTERNS[*]}"
        exit 1
    elif [[ ${#FOUND_FILES[@]} -eq 1 ]]; then
        LIBRARY_FILE="${FOUND_FILES[0]}"
        print_success "找到库文件: $LIBRARY_FILE"
    else
        print_warning "找到多个库文件，使用第一个:"
        for file in "${FOUND_FILES[@]}"; do
            print_info "  $file"
        done
        LIBRARY_FILE="${FOUND_FILES[0]}"
        print_success "使用: $LIBRARY_FILE"
    fi
fi

# 检查最终的库文件是否存在
if [[ ! -f "$LIBRARY_FILE" ]]; then
    print_error "库文件不存在: $LIBRARY_FILE"
    exit 1
fi

print_info "开始符号检查..."
print_info "库文件: $LIBRARY_FILE"
print_info "平台: $PLATFORM"
print_info "架构: $ARCHITECTURE"
echo ""

# 检测环境和工具
ENV_TYPE=$(detect_environment)
print_info "运行环境: $ENV_TYPE"

# 根据平台选择符号检查工具
case "$PLATFORM" in
    "windows")
        WINDOWS_TOOLS=$(detect_windows_tools)
        print_info "Windows工具: $WINDOWS_TOOLS"

        # 根据工具类型设置符号提取方法
        case "$WINDOWS_TOOLS" in
            "llvm-mingw-x64")
                SYMBOL_TOOL="x86_64-w64-mingw32-objdump"
                SYMBOL_METHOD="llvm"
                ARCH_TOOL="x86_64-w64-mingw32-objdump"
                ARCH_ARGS="-f"
                ;;
            "gnu-mingw-x64")
                SYMBOL_TOOL="x86_64-w64-mingw32-objdump"
                SYMBOL_METHOD="gnu"
                ARCH_TOOL="x86_64-w64-mingw32-objdump"
                ARCH_ARGS="-f"
                ;;
            "llvm-mingw-x86")
                SYMBOL_TOOL="i686-w64-mingw32-objdump"
                SYMBOL_METHOD="llvm"
                ARCH_TOOL="i686-w64-mingw32-objdump"
                ARCH_ARGS="-f"
                ;;
            "gnu-mingw-x86")
                SYMBOL_TOOL="i686-w64-mingw32-objdump"
                SYMBOL_METHOD="gnu"
                ARCH_TOOL="i686-w64-mingw32-objdump"
                ARCH_ARGS="-f"
                ;;
            "native-objdump")
                SYMBOL_TOOL="objdump"
                SYMBOL_METHOD="native"
                if command -v file &> /dev/null; then
                    ARCH_TOOL="file"
                    ARCH_ARGS=""
                else
                    ARCH_TOOL=""
                fi
                ;;
            *)
                print_error "Windows平台未找到可用的objdump工具"
                exit 1
                ;;
        esac
        ;;
    "macos"|"ios")
        SYMBOL_TOOL="nm"
        SYMBOL_ARGS="-g"  # macOS使用-g显示全局符号
        ARCH_TOOL="file"
        ;;
    "linux"|"android"|"harmony")
        SYMBOL_TOOL="nm"
        SYMBOL_ARGS="-D"  # Linux使用-D显示动态符号
        ARCH_TOOL="file"
        ;;
    *)
        print_error "不支持的平台: $PLATFORM"
        exit 1
        ;;
esac

# 检查工具是否可用
if ! command -v "$SYMBOL_TOOL" &> /dev/null; then
    print_error "符号检查工具不可用: $SYMBOL_TOOL"
    exit 1
fi

if ! command -v "$ARCH_TOOL" &> /dev/null; then
    print_error "架构检查工具不可用: $ARCH_TOOL"
    exit 1
fi

# 1. 检查架构信息
print_info "1. 检查架构信息"
echo "----------------------------------------"

if [[ -z "$ARCH_TOOL" ]]; then
    print_error "架构检查工具不可用: $ARCH_TOOL"
    ARCH_INFO="架构检查工具不可用"
else
    if [[ -n "$ARCH_ARGS" ]]; then
        ARCH_INFO=$($ARCH_TOOL $ARCH_ARGS "$LIBRARY_FILE" 2>/dev/null || echo "架构检查失败")
    else
        ARCH_INFO=$($ARCH_TOOL "$LIBRARY_FILE" 2>/dev/null || echo "架构检查失败")
    fi
    echo "$ARCH_INFO"
fi

# 验证架构是否匹配
if [[ "$ARCHITECTURE" != "unknown" ]]; then
    case "$ARCHITECTURE" in
        "x86_64"|"amd64")
            if [[ "$ARCH_INFO" =~ (x86-64|x86_64|AMD64) ]]; then
                print_success "架构匹配: $ARCHITECTURE"
            else
                print_warning "架构可能不匹配，期望: $ARCHITECTURE"
            fi
            ;;
        "arm64"|"aarch64")
            if [[ "$ARCH_INFO" =~ (arm64|aarch64|ARM64) ]]; then
                print_success "架构匹配: $ARCHITECTURE"
            else
                print_warning "架构可能不匹配，期望: $ARCHITECTURE"
            fi
            ;;
        "arm32"|"arm")
            if [[ "$ARCH_INFO" =~ (arm|ARM) ]] && [[ ! "$ARCH_INFO" =~ (arm64|aarch64|ARM64) ]]; then
                print_success "架构匹配: $ARCHITECTURE"
            else
                print_warning "架构可能不匹配，期望: $ARCHITECTURE"
            fi
            ;;
        "x86"|"i386")
            if [[ "$ARCH_INFO" =~ (i386|80386|x86) ]] && [[ ! "$ARCH_INFO" =~ (x86-64|x86_64) ]]; then
                print_success "架构匹配: $ARCHITECTURE"
            else
                print_warning "架构可能不匹配，期望: $ARCHITECTURE"
            fi
            ;;
        "universal")
            # macOS Universal Binary - 包含多个架构
            if [[ "$ARCH_INFO" =~ "universal binary" ]]; then
                print_success "架构匹配: $ARCHITECTURE (Universal Binary)"
                # 显示包含的架构
                if [[ "$ARCH_INFO" =~ "x86_64" ]] && [[ "$ARCH_INFO" =~ "arm64" ]]; then
                    print_info "包含架构: x86_64 + arm64"
                elif [[ "$ARCH_INFO" =~ "x86_64" ]]; then
                    print_info "包含架构: x86_64"
                elif [[ "$ARCH_INFO" =~ "arm64" ]]; then
                    print_info "包含架构: arm64"
                fi
            else
                print_warning "架构可能不匹配，期望: Universal Binary"
            fi
            ;;
        "simulator-x86_64"|"simulator-arm64")
            # iOS模拟器架构
            EXPECTED_ARCH=$(echo "$ARCHITECTURE" | cut -d'-' -f2)
            if [[ "$ARCH_INFO" =~ $EXPECTED_ARCH ]]; then
                print_success "架构匹配: $ARCHITECTURE"
            else
                print_warning "架构可能不匹配，期望: $ARCHITECTURE"
            fi
            ;;
        *)
            print_info "未知架构，跳过验证: $ARCHITECTURE"
            ;;
    esac
fi

echo ""

# 2. 提取符号信息
print_info "2. 提取符号信息"
echo "----------------------------------------"

# 根据平台调整符号提取方式
case "$PLATFORM" in
    "windows")
        # Windows DLL符号检查 - 根据工具类型选择方法
        if [[ -n "$SYMBOL_TOOL" ]]; then
            case "$SYMBOL_METHOD" in
                "llvm")
                    # LLVM objdump使用-x参数显示导出表
                    print_info "使用LLVM objdump提取符号..."
                    EXPORT_TABLE=$($SYMBOL_TOOL -x "$LIBRARY_FILE" 2>/dev/null | grep -A 1000 "Export Table:")
                    if [[ -n "$EXPORT_TABLE" ]]; then
                        # LLVM格式：Ordinal RVA Name
                        SYMBOLS=$(echo "$EXPORT_TABLE" | grep -E "^\s*[0-9]+\s+0x[0-9a-fA-F]+\s+[a-zA-Z_]" | awk '{print $3}')
                    else
                        print_warning "LLVM objdump未找到导出表"
                        SYMBOLS=""
                    fi
                    ;;
                "gnu")
                    # GNU objdump使用-p参数显示导出表
                    print_info "使用GNU objdump提取符号..."
                    SYMBOLS=$($SYMBOL_TOOL -p "$LIBRARY_FILE" 2>/dev/null | grep -A 1000 "\[Ordinal/Name Pointer\] Table" | grep -E "^\s*\[\s*[0-9]+\].*[0-9a-fA-F]+\s+[a-zA-Z_]" | awk '{print $6}')
                    ;;
                "native")
                    # 本地objdump，尝试多种方法
                    print_info "使用本地objdump提取符号..."
                    # 先尝试-x参数
                    EXPORT_TABLE=$($SYMBOL_TOOL -x "$LIBRARY_FILE" 2>/dev/null | grep -A 1000 "Export Table:")
                    if [[ -n "$EXPORT_TABLE" ]]; then
                        SYMBOLS=$(echo "$EXPORT_TABLE" | grep -E "^\s*[0-9]+\s+0x[0-9a-fA-F]+\s+[a-zA-Z_]" | awk '{print $3}')
                    else
                        # 再尝试-p参数
                        SYMBOLS=$($SYMBOL_TOOL -p "$LIBRARY_FILE" 2>/dev/null | grep -A 1000 "\[Ordinal/Name Pointer\] Table" | grep -E "^\s*\[\s*[0-9]+\].*[0-9a-fA-F]+\s+[a-zA-Z_]" | awk '{print $6}')
                    fi
                    ;;
                *)
                    print_warning "未知的Windows工具类型: $SYMBOL_METHOD"
                    SYMBOLS=""
                    ;;
            esac
        else
            print_warning "符号提取工具不可用，跳过Windows符号检查"
            SYMBOLS=""
        fi
        ;;
    *)
        # Unix-like系统符号检查
        if [[ -n "$SYMBOL_TOOL" ]]; then
            SYMBOLS=$($SYMBOL_TOOL $SYMBOL_ARGS "$LIBRARY_FILE" 2>/dev/null || echo "")
        else
            SYMBOLS=""
        fi
        ;;
esac

if [[ -z "$SYMBOLS" ]]; then
    print_warning "无法提取符号信息，可能是静态库或工具不兼容"
    exit 0
fi

# 3. 检查cr_前缀符号
print_info "3. 检查cr_前缀符号导出"
echo "----------------------------------------"

# 查找cr_sqlite3_和cr_sqlcipher_符号
CR_SQLITE_SYMBOLS=$(echo "$SYMBOLS" | grep -E "(cr_sqlite3_|cr_sqlcipher_)" | grep -v " U " || true)
if [[ -n "$CR_SQLITE_SYMBOLS" && "$CR_SQLITE_SYMBOLS" != "" ]]; then
    CR_SQLITE_COUNT=$(echo "$CR_SQLITE_SYMBOLS" | wc -l | tr -d ' ')
else
    CR_SQLITE_COUNT=0
fi

if [[ $CR_SQLITE_COUNT -gt 0 ]]; then
    print_success "找到 $CR_SQLITE_COUNT 个cr_前缀符号"
    echo "前10个cr_前缀符号:"
    echo "$CR_SQLITE_SYMBOLS" | head -10 | sed 's/^/  /'
    
    if [[ $CR_SQLITE_COUNT -gt 10 ]]; then
        echo "  ... (还有 $((CR_SQLITE_COUNT - 10)) 个符号)"
    fi
else
    print_error "未找到cr_前缀符号！这可能表示符号导出有问题"
fi

echo ""

# 4. 检查OpenSSL符号隐藏
print_info "4. 检查OpenSSL符号隐藏"
echo "----------------------------------------"

# 查找OpenSSL相关符号（应该被隐藏）
OPENSSL_SYMBOLS=$(echo "$SYMBOLS" | grep -E "(SSL_|EVP_|BIO_|CRYPTO_|OPENSSL_|RSA_|AES_|SHA)" | grep -v " U " || true)
if [[ -n "$OPENSSL_SYMBOLS" && "$OPENSSL_SYMBOLS" != "" ]]; then
    OPENSSL_COUNT=$(echo "$OPENSSL_SYMBOLS" | wc -l | tr -d ' ')
else
    OPENSSL_COUNT=0
fi

if [[ $OPENSSL_COUNT -eq 0 ]]; then
    print_success "OpenSSL符号已正确隐藏"
else
    print_warning "发现 $OPENSSL_COUNT 个OpenSSL符号未被隐藏"
    echo "前10个OpenSSL符号:"
    echo "$OPENSSL_SYMBOLS" | head -10 | sed 's/^/  /'
    
    if [[ $OPENSSL_COUNT -gt 10 ]]; then
        echo "  ... (还有 $((OPENSSL_COUNT - 10)) 个符号)"
    fi
fi

echo ""

# 5. 统计总体符号情况
print_info "5. 符号统计总结"
echo "----------------------------------------"

# 统计不同类型的符号
if [[ "$PLATFORM" == "windows" ]]; then
    # Windows平台：符号已经是纯函数名列表
    if [[ -n "$SYMBOLS" && "$SYMBOLS" != "" ]]; then
        TOTAL_SYMBOLS=$(echo "$SYMBOLS" | wc -l | tr -d ' ')
        EXPORTED_SYMBOLS=$TOTAL_SYMBOLS  # Windows导出表中的都是导出符号
    else
        TOTAL_SYMBOLS=0
        EXPORTED_SYMBOLS=0
    fi
else
    # Unix平台：使用nm格式解析
    TOTAL_SYMBOLS_RAW=$(echo "$SYMBOLS" | grep -v " U " || true)
    if [[ -n "$TOTAL_SYMBOLS_RAW" && "$TOTAL_SYMBOLS_RAW" != "" ]]; then
        TOTAL_SYMBOLS=$(echo "$TOTAL_SYMBOLS_RAW" | wc -l | tr -d ' ')
    else
        TOTAL_SYMBOLS=0
    fi

    EXPORTED_SYMBOLS_RAW=$(echo "$SYMBOLS" | grep -E " T | D | B " || true)
    if [[ -n "$EXPORTED_SYMBOLS_RAW" && "$EXPORTED_SYMBOLS_RAW" != "" ]]; then
        EXPORTED_SYMBOLS=$(echo "$EXPORTED_SYMBOLS_RAW" | wc -l | tr -d ' ')
    else
        EXPORTED_SYMBOLS=0
    fi
fi

echo "总符号数: $TOTAL_SYMBOLS"
echo "导出符号数: $EXPORTED_SYMBOLS"
echo "cr_前缀符号数: $CR_SQLITE_COUNT"
echo "OpenSSL符号数: $OPENSSL_COUNT"

# 6. 生成检查报告
echo ""
print_info "6. 检查结果总结"
echo "========================================"

ISSUES=0

# 检查cr_前缀符号
if [[ $CR_SQLITE_COUNT -gt 0 ]]; then
    print_success "✅ cr_前缀符号导出正常 ($CR_SQLITE_COUNT 个)"
else
    print_error "❌ cr_前缀符号导出异常"
    ISSUES=$((ISSUES + 1))
fi

# 检查OpenSSL符号隐藏
if [[ $OPENSSL_COUNT -eq 0 ]]; then
    print_success "✅ OpenSSL符号隐藏正常"
else
    print_warning "⚠️  OpenSSL符号未完全隐藏 ($OPENSSL_COUNT 个)"
    ISSUES=$((ISSUES + 1))
fi

# 检查总体符号数量
if [[ $EXPORTED_SYMBOLS -gt 0 ]]; then
    print_success "✅ 库文件包含导出符号 ($EXPORTED_SYMBOLS 个)"
else
    print_error "❌ 库文件无导出符号"
    ISSUES=$((ISSUES + 1))
fi

echo ""
if [[ $ISSUES -eq 0 ]]; then
    print_success "🎉 所有符号检查通过！"
    exit 0
else
    print_warning "⚠️  发现 $ISSUES 个问题，请检查符号导出配置"
    exit 1
fi
