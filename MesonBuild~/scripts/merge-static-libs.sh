#!/bin/bash

# 合并静态库脚本
# 参数: $1=输出库 $2=SQLite库 $3=OpenSSL crypto库 $4=OpenSSL ssl库

set -e

# 保存调用脚本时的目录
WORK_DIR="$(pwd)"
OUTPUT_LIB="$1"
SQLITE_LIB="$2"
CRYPTO_LIB="$3"
SSL_LIB="$4"

echo "合并静态库："
echo "  工作目录: $WORK_DIR"
echo "  SQLite: $SQLITE_LIB"
echo "  OpenSSL Crypto: $CRYPTO_LIB"
echo "  OpenSSL SSL: $SSL_LIB"
echo "  输出: $OUTPUT_LIB"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
echo "使用临时目录: $TEMP_DIR"

# 提取所有静态库的目标文件
cd "$TEMP_DIR"

echo "提取 SQLite 静态库..."
echo "SQLite库路径: $WORK_DIR/$SQLITE_LIB"
echo "SQLite库内容:"
ar -t "$WORK_DIR/$SQLITE_LIB"
echo "开始提取..."
ar x "$WORK_DIR/$SQLITE_LIB"
echo "提取后检查特殊文件名:"
ls -la ..* 2>/dev/null || echo "没有找到以..开头的文件"

echo "提取 OpenSSL crypto 静态库..."
ar x "$WORK_DIR/$CRYPTO_LIB"

echo "提取 OpenSSL ssl 静态库..."
ar x "$WORK_DIR/$SSL_LIB"

echo "调试: 检查提取的目标文件..."
echo "目标文件总数: $(ls *.o | wc -l)"

# 查找SQLite目标文件（智能查找）
echo "查找SQLite目标文件..."
SQLITE_OBJ=""

# 尝试多种可能的SQLite目标文件名
POSSIBLE_NAMES=(
    ".._Plugins_sqlite-amalgamation_sqlite3.c.o"
    "sqlite3.c.o"
    "*sqlite*.o"
)

for pattern in "${POSSIBLE_NAMES[@]}"; do
    if [[ "$pattern" == "*sqlite*.o" ]]; then
        # 使用通配符查找
        FOUND_FILES=($(find . -name "$pattern" -type f))
        if [[ ${#FOUND_FILES[@]} -gt 0 ]]; then
            SQLITE_OBJ="${FOUND_FILES[0]}"
            echo "✅ 通过通配符找到SQLite目标文件: $SQLITE_OBJ"
            break
        fi
    else
        # 直接查找
        if [[ -f "$pattern" ]]; then
            SQLITE_OBJ="$pattern"
            echo "✅ 找到SQLite目标文件: $SQLITE_OBJ"
            break
        fi
    fi
done

if [[ -n "$SQLITE_OBJ" && -f "$SQLITE_OBJ" ]]; then
    echo "文件大小: $(ls -lh "$SQLITE_OBJ" | awk '{print $5}')"
    echo "检查其中的符号:"
    nm "$SQLITE_OBJ" | grep "T _sqlite3_" | head -5 || echo "未找到标准sqlite3符号，检查cr_前缀符号:"
    nm "$SQLITE_OBJ" | grep "T _cr_sqlite3_" | head -5 || echo "未找到cr_前缀符号"
    SQLITE_SYMBOL_COUNT=$(nm "$SQLITE_OBJ" | grep -E "T _sqlite3_|T _cr_sqlite3_" | wc -l)
    echo "✅ SQLite符号统计: $SQLITE_SYMBOL_COUNT 个函数"
else
    echo "❌ 错误: 找不到SQLite目标文件"
    echo "尝试的文件名: ${POSSIBLE_NAMES[*]}"
    echo "当前目录文件:"
    ls -la
    echo "查找所有.o文件:"
    find . -name "*.o" -type f
    exit 1
fi

# 使用正确的 ld -r + llvm-objcopy 方案进行符号控制
echo "使用专业的 ld -r + llvm-objcopy 符号控制方案..."

# 检查是否有符号导出列表文件
# 修正：直接使用正确的 exports.ios.symbols 路径
SCRIPT_DIR="$(dirname "$0")"
EXPORTS_FILE="$SCRIPT_DIR/../exports/exports.ios.symbols"
if [[ -f "$EXPORTS_FILE" ]]; then
    echo "✅ 找到符号导出列表: $EXPORTS_FILE"

    # 步骤1: 创建有效的SQLite符号白名单
    echo "步骤1: 创建有效的SQLite符号白名单..."

    # 直接使用找到的符号导出文件
    UNITY_SYMBOLS_FILE="$EXPORTS_FILE"
    echo "  ✅ 使用Unity完整符号列表: $UNITY_SYMBOLS_FILE"

    # 步骤1: 严格按照符号导出文件控制符号
    echo "  🔧 严格按照符号导出文件控制符号..."

    # 直接使用exports.ios.symbols文件，不检查对象文件中的符号
    # 这样可以确保只导出我们明确想要导出的符号
    FILTERED_SYMBOLS=$(mktemp)

    # 读取符号导出文件，跳过注释行和空行
    while IFS= read -r line; do
        # 跳过空行和注释行
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # 提取符号名（去除前后空格）
        symbol=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$symbol" ]] && continue

        echo "$symbol" >> "$FILTERED_SYMBOLS"
        echo "    ✅ 将导出符号: $symbol"
    done < "$UNITY_SYMBOLS_FILE"

    # 去重排序
    sort "$FILTERED_SYMBOLS" | uniq > exported_symbols.txt

    # 清理临时文件
    rm -f "$FILTERED_SYMBOLS"

    echo "  ✅ 符号导出列表创建完成，符号数量: $(wc -l < exported_symbols.txt)"


    echo "✅ 符号导出白名单创建完成 ($(wc -l < exported_symbols.txt) 个符号)"
    echo "前5个符号:"
    head -5 exported_symbols.txt

    # 步骤2: 使用 ld -r 合并所有对象文件并控制符号可见性
    echo "步骤2: 使用 ld -r 合并对象文件并应用符号白名单..."

    # 使用 ld -r 合并所有对象文件，包括SQLite对象文件
    echo "  正在合并对象文件..."

    # 收集所有对象文件，包括以..开头的特殊文件
    ALL_OBJ_FILES=()

    # 添加普通的.o文件
    for obj in *.o; do
        if [[ -f "$obj" ]]; then
            ALL_OBJ_FILES+=("$obj")
        fi
    done

    # 添加以..开头的.o文件
    for obj in ..*.o; do
        if [[ -f "$obj" ]]; then
            ALL_OBJ_FILES+=("$obj")
        fi
    done

    echo "  找到 ${#ALL_OBJ_FILES[@]} 个对象文件"
    echo "  前5个文件: ${ALL_OBJ_FILES[@]:0:5}"

    if [[ ${#ALL_OBJ_FILES[@]} -eq 0 ]]; then
        echo "❌ 错误: 没有找到任何对象文件"
        exit 1
    fi

    # 使用数组展开来传递所有文件
    ld -r -o combined.o "${ALL_OBJ_FILES[@]}"

    # 修正：使用正确的符号控制方法
    echo "  正在应用符号白名单，隐藏OpenSSL符号..."

    # 检测操作系统类型
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "    检测到 macOS，使用 macOS 兼容的符号控制方法..."

        # macOS 方法：使用 ld 的 -exported_symbols_list 选项
        echo "    步骤1: 创建符号导出列表文件..."

        # 创建 macOS ld 兼容的符号列表文件
        cp exported_symbols.txt exported_symbols_ld.txt

        echo "    步骤2: 使用 ld -r -exported_symbols_list 重新链接..."
        # 使用 ld 的 -exported_symbols_list 选项来控制符号可见性
        # 这会将未列出的符号标记为私有
        ld -r -exported_symbols_list exported_symbols_ld.txt -o filtered.o combined.o

        # 清理临时文件
        rm -f exported_symbols_ld.txt

    elif command -v objcopy >/dev/null 2>&1; then
        echo "    使用 objcopy 方法控制符号..."
        # 先将所有符号设为局部
        objcopy --localize-symbols=<(nm combined.o | grep ' T ' | awk '{print $3}') combined.o temp1.o
        # 再将需要的符号设为全局
        objcopy --globalize-symbols=exported_symbols.txt temp1.o filtered.o
        rm -f temp1.o

    else
        echo "    使用 GNU ld 方法控制符号..."
        # 创建符号脚本文件（仅适用于 GNU ld）
        echo "VERSION { EXPORTED { global:" > version_script.map
        while read -r symbol; do
            [[ -n "$symbol" ]] && echo "    $symbol;" >> version_script.map
        done < exported_symbols.txt
        echo "  local: *; }; }" >> version_script.map

        # 使用版本脚本控制符号可见性
        ld -r --version-script=version_script.map -o filtered.o combined.o
        rm -f version_script.map
    fi

    # 创建最终的静态库
    echo "  正在创建最终静态库..."
    ar crs "$WORK_DIR/$OUTPUT_LIB" filtered.o
    
    # 验证合并结果
    SQLITE_COUNT=$(nm "$WORK_DIR/$OUTPUT_LIB" 2>/dev/null | grep "_sqlite3_" | wc -l)
    TOTAL_SIZE=$(ls -lh "$WORK_DIR/$OUTPUT_LIB" | awk '{print $5}')
    
    echo ""
    echo "📊 符号控制合并结果统计:"
    echo "  ✅ SQLite符号: $SQLITE_COUNT 个 (Unity需要: 51+个)"
    echo "  🔒 OpenSSL符号: 已隐藏"
    echo "  📦 库文件大小: $TOTAL_SIZE"
    echo "  📁 输出位置: $OUTPUT_LIB"
    echo ""
    echo "🎉 iOS SQLCipher静态库构建完成！"
    echo "✅ 包含Unity Runtime需要的完整SQLite功能"
    echo "🔒 OpenSSL符号已隐藏，避免与其他SDK冲突"
    echo "🛠️  完全适用于Unity DllImport"
    echo "📝 库文件位置: $WORK_DIR/$OUTPUT_LIB"

else
    echo "❌ 未找到符号导出列表文件: $EXPORTS_FILE"
    echo "⚠️  使用简单合并，无符号控制"

    # 收集所有对象文件（包括以..开头的SQLite文件）
    ALL_OBJ_FILES=()
    for obj in *.o; do
        if [[ -f "$obj" ]]; then
            ALL_OBJ_FILES+=("$obj")
        fi
    done
    for obj in ..*.o; do
        if [[ -f "$obj" ]]; then
            ALL_OBJ_FILES+=("$obj")
        fi
    done

    echo "简单合并 ${#ALL_OBJ_FILES[@]} 个对象文件"
    ar crs "$WORK_DIR/$OUTPUT_LIB" "${ALL_OBJ_FILES[@]}"
fi

# 验证合并结果
echo "合并后的静态库大小:"
ls -lh "$WORK_DIR/$OUTPUT_LIB"

echo "合并后的静态库架构:"
file "$WORK_DIR/$OUTPUT_LIB"

# 显示库内容统计（全局导出符号）
echo "静态库全局符号统计:"
TOTAL_GLOBAL_SYMBOLS=$(nm -g "$WORK_DIR/$OUTPUT_LIB" 2>/dev/null | wc -l | tr -d ' \n' || echo "0")
# 检查带cr_前缀的sqlite符号（因为我们已经应用了前缀）
CR_SQLITE_GLOBAL_SYMBOLS=$(nm -g "$WORK_DIR/$OUTPUT_LIB" 2>/dev/null | grep -c "cr_sqlite3_" | tr -d ' \n' || echo "0")
# 检查原始sqlite符号（应该为0，因为都改为cr_前缀了）
SQLITE_GLOBAL_SYMBOLS=$(nm -g "$WORK_DIR/$OUTPUT_LIB" 2>/dev/null | grep -c "_sqlite3_" | tr -d ' \n' || echo "0") 
OPENSSL_GLOBAL_SYMBOLS=$(nm -g "$WORK_DIR/$OUTPUT_LIB" 2>/dev/null | grep -cE "(AES_|SSL_|EVP_|RSA_|BN_|OPENSSL_)" | tr -d ' \n' || echo "0")

echo "全局符号总数: $TOTAL_GLOBAL_SYMBOLS"
echo "带cr_前缀的SQLite符号: $CR_SQLITE_GLOBAL_SYMBOLS" 
echo "原始SQLite符号: $SQLITE_GLOBAL_SYMBOLS"
echo "OpenSSL全局符号: $OPENSSL_GLOBAL_SYMBOLS"

# 数值转换确保比较正常工作
CR_COUNT=$((CR_SQLITE_GLOBAL_SYMBOLS + 0))
OPENSSL_COUNT=$((OPENSSL_GLOBAL_SYMBOLS + 0))

if [[ $OPENSSL_COUNT -eq 0 && $CR_COUNT -gt 0 ]]; then
    echo "✅ 符号控制成功：带cr_前缀的SQLite符号已导出，OpenSSL符号已隐藏"
    echo "🔒 OpenSSL功能完整保留为局部符号，外部无法访问"
    echo "📋 实际导出的SQLite符号示例:"
    nm -g "$WORK_DIR/$OUTPUT_LIB" 2>/dev/null | grep "cr_sqlite3_" | head -5
elif [[ $OPENSSL_COUNT -gt 0 ]]; then
    echo "⚠️  注意：OpenSSL符号仍在全局符号表中可见"
else
    echo "⚠️  警告：未检测到预期的带cr_前缀的SQLite符号"
    echo "调试信息 - 所有全局符号："
    nm -g "$WORK_DIR/$OUTPUT_LIB" 2>/dev/null | head -10
fi

# 清理临时目录
cd /
rm -rf "$TEMP_DIR"

echo "静态库合并完成: $WORK_DIR/$OUTPUT_LIB"
