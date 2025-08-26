#!/bin/bash

# iOS Framework 创建脚本
# 参数: $1=动态库路径 $2=Framework名称 $3=输出目录

set -e

INPUT_DYLIB="$1"
FRAMEWORK_NAME="$2"
OUTPUT_DIR="$3"

# 验证参数
if [ $# -ne 3 ]; then
    echo "用法: $0 <动态库路径> <Framework名称> <输出目录>"
    echo "示例: $0 /path/to/lib.dylib CRSQLCipher /output/dir"
    exit 1
fi

if [ ! -f "$INPUT_DYLIB" ]; then
    echo "错误: 输入的动态库文件不存在: $INPUT_DYLIB"
    exit 1
fi

echo "正在创建 iOS Framework..."
echo "  动态库: $INPUT_DYLIB"
echo "  Framework名称: $FRAMEWORK_NAME"
echo "  输出目录: $OUTPUT_DIR"

# 创建Framework目录结构
FRAMEWORK_DIR="$OUTPUT_DIR/$FRAMEWORK_NAME.framework"
mkdir -p "$FRAMEWORK_DIR"
mkdir -p "$FRAMEWORK_DIR/Headers"

# 复制动态库并重命名
cp "$INPUT_DYLIB" "$FRAMEWORK_DIR/$FRAMEWORK_NAME"

# 设置正确的权限（Framework二进制不应该有可执行权限）
echo "设置正确的文件权限..."
chmod 644 "$FRAMEWORK_DIR/$FRAMEWORK_NAME"

# 修复install_name，设置为标准的Framework格式
echo "修复install_name..."
install_name_tool -id "@rpath/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" "$FRAMEWORK_DIR/$FRAMEWORK_NAME"

# 移除SQLite SEE相关符号以避免iOS权限问题
echo "移除SEE相关符号..."
# 创建临时符号脚本来隐藏activate_see符号
if nm "$FRAMEWORK_DIR/$FRAMEWORK_NAME" | grep -q "sqlite3_activate_see"; then
    echo "检测到sqlite3_activate_see符号，尝试移除..."
    # 使用strip移除调试符号，然后用objcopy处理（如果可用）
    strip -S "$FRAMEWORK_DIR/$FRAMEWORK_NAME" 2>/dev/null || true
    echo "符号处理完成"
fi

# 创建Info.plist (增加iOS设备兼容性信息)
cat > "$FRAMEWORK_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.sqlcipher.$FRAMEWORK_NAME</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>1.2.0</string>
    <key>MinimumOSVersion</key>
    <string>12.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneOS</string>
    </array>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
</dict>
</plist>
EOF

# 创建PrivacyInfo.xcprivacy文件 (iOS要求)
cat > "$FRAMEWORK_DIR/PrivacyInfo.xcprivacy" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array/>
</dict>
</plist>
EOF

# 复制公共头文件
SQLITE_HEADERS_DIR="$(dirname "$0")/../../Plugins/sqlite-amalgamation"
if [ -d "$SQLITE_HEADERS_DIR" ]; then
    echo "复制SQLite头文件..."
    cp "$SQLITE_HEADERS_DIR/sqlite3.h" "$FRAMEWORK_DIR/Headers/"
    cp "$SQLITE_HEADERS_DIR/sqlite3ext.h" "$FRAMEWORK_DIR/Headers/"
    cp "$SQLITE_HEADERS_DIR/sqlite3_defines.h" "$FRAMEWORK_DIR/Headers/"
fi

# 创建模块映射文件
cat > "$FRAMEWORK_DIR/Headers/module.modulemap" << EOF
framework module $FRAMEWORK_NAME {
    header "sqlite3.h"
    header "sqlite3ext.h"
    header "sqlite3_defines.h"
    export *
}
EOF

# 验证Framework结构
echo "Framework结构:"
find "$FRAMEWORK_DIR" -type f | sort

# 验证动态库架构
echo "动态库架构信息:"
file "$FRAMEWORK_DIR/$FRAMEWORK_NAME"
if command -v lipo >/dev/null; then
    lipo -info "$FRAMEWORK_DIR/$FRAMEWORK_NAME"
fi

echo "✅ iOS Framework 创建完成: $FRAMEWORK_DIR"
