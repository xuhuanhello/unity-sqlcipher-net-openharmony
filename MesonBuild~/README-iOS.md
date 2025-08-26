# iOS 平台构建指南

本文档介绍如何为iOS平台构建SQLCipher动态库并打包为Framework格式。

## 概述

iOS构建方案的特点：
- ✅ **Framework封装**: 生成标准的iOS Framework (`CRSQLCipher.framework`)
- ✅ **静态链接OpenSSL**: OpenSSL 3.0.8静态链接到动态库中
- ✅ **符号隐藏**: 只导出SQLite/SQLCipher API，隐藏OpenSSL符号
- ✅ **支持iOS 12+**: 最小部署目标为iOS 12.0
- ✅ **Xcode工具链**: 使用官方Xcode工具链构建
- ✅ **设备和模拟器**: 支持真机和模拟器构建

## 环境要求

### 必要软件
- macOS 系统
- Xcode (包含iOS SDK)
- Meson 1.2.0+
- Python 3

### 安装Meson
```bash
pip3 install meson ninja
```

## 构建命令

### iOS 设备版本 (ARM64)
```bash
cd MesonBuild
./scripts/build-platform.sh ios-arm64 release
```

### iOS 模拟器版本
```bash
# ARM64 模拟器 (Apple Silicon Mac)
./scripts/build-platform.sh ios-simulator-arm64 debug

# x86_64 模拟器 (Intel Mac)
./scripts/build-platform.sh ios-simulator-x86_64 debug
```

### 一键测试
```bash
# 自动测试iOS构建流程
./test-ios-build.sh
```

## 输出文件

构建完成后，Framework将生成在以下位置：

### iOS 设备版本
```
../Plugins/lib/ios/CRSQLCipher.framework/
├── CRSQLCipher           # 动态库文件
├── Info.plist           # Framework信息
└── Headers/             # 公共头文件
    ├── sqlite3.h
    ├── sqlite3ext.h
    └── module.modulemap
```

### iOS 模拟器版本
```
../Plugins/lib/ios-simulator/CRSQLCipher.framework/
```

## Framework详细信息

| 属性 | 值 |
|------|-----|
| Framework名称 | CRSQLCipher.framework |
| Bundle ID | com.sqlcipher.CRSQLCipher |
| 最小iOS版本 | iOS 12.0 |
| 架构支持 | arm64 (设备), arm64/x86_64 (模拟器) |
| OpenSSL版本 | 3.0.8 (静态链接) |
| SQLCipher | 完整支持 |

## 符号隐藏验证

可以使用以下命令验证符号隐藏效果：

```bash
# 查看导出符号
nm -D ../Plugins/lib/ios/CRSQLCipher.framework/CRSQLCipher | grep -E "(sqlite3_|sqlcipher_)"

# 检查是否有OpenSSL符号泄露
nm -D ../Plugins/lib/ios/CRSQLCipher.framework/CRSQLCipher | grep -iE "(ssl_|crypto_|evp_)"
```

正确配置下，应该只看到SQLite/SQLCipher符号，不应有OpenSSL符号。

## 与macOS的差异

| 方面 | macOS | iOS |
|------|-------|-----|
| 架构 | Universal Binary (arm64+x86_64) | 单架构 (arm64) |
| 文件格式 | .dylib | .framework |
| 库名称 | libgilzoide-sqlite-net.dylib | CRSQLCipher.framework |
| 符号隐藏 | exported_symbols_list | 相同机制 |
| OpenSSL静态链接 | ✅ | ✅ |
| Bitcode | N/A | 支持 (-fembed-bitcode) |

## 在Unity中使用

1. 将生成的Framework复制到Unity项目的`Assets/Plugins/iOS/`目录
2. 在Unity Inspector中配置Framework设置：
   - Platform: iOS
   - SDK: Any
   - Placeholder: `Plugins/iOS/CRSQLCipher.framework`
   - Framework Dependencies: 可能需要添加 `libz.tbd`

## 代码签名

### 自动签名
```bash
# 在构建时指定签名身份
./scripts/build-platform.sh ios-arm64 release -Dios_codesign_identity="iPhone Developer"
```

### 手动签名
```bash
codesign -s "iPhone Developer" --deep --force ../Plugins/lib/ios/CRSQLCipher.framework
```

## 故障排除

### 常见问题

1. **找不到iOS SDK**
   ```
   错误: 未找到 iOS SDK
   解决: 确保Xcode已正确安装，运行 xcode-select --install
   ```

2. **架构不匹配**
   ```
   错误: 架构 xxx 不支持
   解决: 检查目标设备架构，选择正确的构建配置
   ```

3. **OpenSSL符号泄露**
   ```
   错误: 检测到OpenSSL符号
   解决: 检查exports.symbols文件，确保符号隐藏正确配置
   ```

### 调试技巧

```bash
# 查看Framework结构
find ../Plugins/lib/ios/CRSQLCipher.framework -type f

# 检查动态库信息
file ../Plugins/lib/ios/CRSQLCipher.framework/CRSQLCipher
lipo -info ../Plugins/lib/ios/CRSQLCipher.framework/CRSQLCipher

# 检查依赖库
otool -L ../Plugins/lib/ios/CRSQLCipher.framework/CRSQLCipher
```

## 高级配置

### 自定义Framework名称
编辑 `meson.build` 中的 `library_name` 变量：
```meson
library_name = 'YourCustomName'
```

### 修改最小iOS版本
编辑交叉编译文件中的 `-miphoneos-version-min` 参数：
```ini
c_args = ['-miphoneos-version-min=13.0', ...]
```

### 启用Bitcode（可选）
Bitcode已默认启用，如需禁用：
```ini
# 移除 cross-files 中的 -fembed-bitcode 参数
```

## 性能和大小

| 指标 | 典型值 |
|------|--------|
| Framework大小 | ~15-20MB |
| 静态链接OpenSSL | ~10MB |
| SQLCipher核心 | ~5MB |
| 启动时间影响 | 最小 |

Framework采用动态链接方式，在应用启动时加载，对启动时间影响很小。
