#!/usr/bin/env bash

# 提取Unity Runtime中所有DllImport的SQLite符号
# 输出：unity_required_symbols.txt

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MESON_BUILD_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$MESON_BUILD_DIR")"
RUNTIME_DIR="$PROJECT_ROOT/Runtime"
OUTPUT_FILE="$SCRIPT_DIR/unity_required_symbols.txt"

echo "=== 🔍 Unity Runtime SQLite符号提取工具 ==="
echo "扫描目录: $RUNTIME_DIR"
echo "输出文件: $OUTPUT_FILE"
echo ""

# 检查Runtime目录是否存在
if [[ ! -d "$RUNTIME_DIR" ]]; then
    echo "❌ 错误: Runtime目录不存在: $RUNTIME_DIR"
    exit 1
fi

# 创建临时文件
TEMP_FILE=$(mktemp)

echo "📂 扫描所有.cs文件中的DllImport..."

# 找到所有.cs文件并搜索DllImport
find "$RUNTIME_DIR" -name "*.cs" -type f | while read -r cs_file; do
    echo "  处理: $(basename "$cs_file")"
    
    # 提取DllImport的EntryPoint
    grep "EntryPoint.*=" "$cs_file" | \
        sed -n 's/.*EntryPoint *= *"\([^"]*\)".*/\1/p' >> "$TEMP_FILE" 2>/dev/null || true
done

# 去重并排序
echo ""
echo "📊 统计结果:"
sort "$TEMP_FILE" | uniq > "$OUTPUT_FILE"

# 显示统计信息
TOTAL_SYMBOLS=$(wc -l < "$OUTPUT_FILE")
echo "  总共找到: $TOTAL_SYMBOLS 个唯一的SQLite函数"

# 显示前10个符号作为预览
echo ""
echo "🔖 符号预览 (前10个):"
head -10 "$OUTPUT_FILE" | sed 's/^/  • /'

# 显示完整列表
echo ""
echo "📝 完整符号列表:"
cat "$OUTPUT_FILE"

# 与原始SQLite库对比
echo ""
echo "📊 与原始SQLite库对比:"
if [[ -d "$PROJECT_ROOT/MesonBuild/build-ios-arm64" ]]; then
    SQLITE_OBJ=$(find "$PROJECT_ROOT/MesonBuild/build-ios-arm64" -name "*.o" -path "*sqlite-amalgamation*" | head -1)
    if [[ -f "$SQLITE_OBJ" ]]; then
        ORIGINAL_COUNT=$(nm "$SQLITE_OBJ" 2>/dev/null | grep "T _sqlite3_" | wc -l)
        echo "  Unity需要: $TOTAL_SYMBOLS 个符号"
        echo "  SQLite原始: $ORIGINAL_COUNT 个符号"
        if command -v bc > /dev/null 2>&1; then
            COVERAGE=$(echo "scale=1; $TOTAL_SYMBOLS * 100 / $ORIGINAL_COUNT" | bc)
            echo "  覆盖率: ${COVERAGE}%"
        fi
    else
        echo "  未找到SQLite对象文件，请先构建项目"
    fi
else
    echo "  未找到构建目录，请先构建项目"
fi

# 生成符号白名单格式（用于exports）
EXPORTS_FILE="$SCRIPT_DIR/unity_symbols_exports.txt"
echo ""
echo "🔧 生成符号导出白名单: $EXPORTS_FILE"
sed 's/^/_/' "$OUTPUT_FILE" > "$EXPORTS_FILE"
echo "  已生成 $(wc -l < "$EXPORTS_FILE") 个符号的导出白名单"

# 清理临时文件
rm -f "$TEMP_FILE"

echo ""
echo "✅ 完成！结果保存在: $OUTPUT_FILE"
echo "📋 导出白名单保存在: $EXPORTS_FILE"
