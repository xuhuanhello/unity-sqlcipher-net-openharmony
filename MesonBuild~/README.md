# Unity SQLCipher.NET Meson 构建系统

这是一个基于 Meson 的构建系统，用于为多个平台构建 Unity SQLCipher.NET 的原生加密库，使用 OpenSSL 作为加密后端。

## 系统要求

- [Meson](https://mesonbuild.com/) >= 0.56
- [Ninja](https://ninja-build.org/)
- 对应平台的编译器工具链
- **源码要求**：`../Plugins/sqlite-amalgamation/sqlite3.c` 必须是 SQLCipher 源码

## 支持的平台

| 平台 | 架构 | 工具链要求 | 状态 |
|------|------|------------|------|
| Windows | x86_64, x86 | MinGW-w64 | ✅ 完全支持 |
| Windows | ARM64 | MinGW-w64 (ARM64) | ⚠️ 受限支持* |
| Linux | x86_64 | GCC | ✅ 完全支持 |
| macOS | Universal (ARM64+x86_64) | Xcode | ✅ 完全支持 |
| iOS | ARM64 | Xcode | ✅ 完全支持 |
| iOS Simulator | ARM64, x86_64 | Xcode | ✅ 完全支持 |
| Android | ARM64, ARM32, x86_64, x86 | Android NDK | ✅ 完全支持 |

**\* Windows ARM64 限制说明**: 大多数Linux发行版不提供ARM64 MinGW工具链，可使用Docker或CI/CD方案。

## 主要特性

- ✅ **SQLCipher 加密支持**：使用 OpenSSL 3.0.8 作为加密后端
- ✅ **静态链接 OpenSSL**：避免版本冲突，确保可移植性
- ✅ **符号隐藏**：OpenSSL 符号完全隐藏，防止与其他库冲突
- ✅ **iOS Framework 支持**：自动打包为标准iOS Framework格式
- ✅ **16KB 对齐支持**：Android 平台自动配置 16KB 页面对齐
- ✅ **多平台交叉编译**：支持 Windows、Linux、macOS、iOS、Android
- ✅ **版本可控**：强制使用指定的 OpenSSL 3.0.8 版本

## 快速开始

### 1. 环境检查（推荐）

首先运行环境检查脚本，确保所有必要的工具都已安装：

```bash
cd scripts
./check-env.sh
```

这个脚本会：
- 🔍 检查基础构建工具（meson, ninja, build-essential）
- 🔍 检查交叉编译工具链（mingw, Android NDK）
- 📦 自动提示安装缺失的工具
- 🖥️ 支持 Linux 和 macOS 系统
- ⚙️ 自动设置环境变量（如 ANDROID_NDK_ROOT）

如果所有检查都通过，你可以直接跳到[构建步骤](#4-构建)。

**重要提示**: Windows ARM64支持受限，详见[平台限制](#平台限制)。

### 2. 手动安装依赖（可选）

如果不使用自动检查脚本，可以手动安装：

```bash
# Ubuntu/Debian
sudo apt install meson ninja-build

# macOS
brew install meson ninja

# Windows (使用 MSYS2)
pacman -S mingw-w64-x86_64-meson mingw-w64-x86_64-ninja
```

#### MinGW (Windows交叉编译)
```bash
# Ubuntu/Debian
sudo apt install mingw-w64

# macOS
brew install mingw-w64
```

#### Android NDK
```bash
export ANDROID_NDK_ROOT=/path/to/your/android-ndk
```

### 3. SQLCipher 配置

**重要**：SQLCipher 的所有配置现在统一在 `../Plugins/sqlite-amalgamation/sqlite3_defines.h` 文件中管理。

**常用配置项**：
```c
#define SQLITE_TEMP_STORE 2                    // 临时存储：2=内存优先, 3=仅内存 (SQLCipher要求>=2)
#define SQLITE_THREADSAFE 1                    // 线程安全：0=禁用, 1=启用
#define SQLITE_DEFAULT_FOREIGN_KEYS 1          // 外键：0=禁用, 1=启用
```

**重要限制**：
- ⚠️ SQLCipher 不支持文件临时存储模式 (`SQLITE_TEMP_STORE=0` 或 `1`)
- ✅ 必须使用内存临时存储模式 (`SQLITE_TEMP_STORE=2` 或 `3`)
- 📝 这是 SQLCipher 的安全特性，确保临时数据不会以明文形式写入磁盘

### 4. 构建

#### 构建所有平台

#### 构建单个平台
```bash
# 构建 Linux x86_64 (Release)
./scripts/build-platform.sh linux-x86_64

# 构建 Windows x86_64 (Debug)
./scripts/build-platform.sh windows-x86_64 debug

# 构建 iOS 设备版本
./scripts/build-platform.sh ios-arm64

# 构建 iOS 模拟器版本
./scripts/build-platform.sh ios-simulator-arm64

# 构建 Android ARM64
./scripts/build-platform.sh android-arm64
```

#### 批量构建
```bash
# 构建所有平台 (包括iOS)
./scripts/build-all.sh

# 构建所有 iOS 平台
./scripts/build-all.sh ios

# 构建所有 Android 平台 (Debug模式)
./scripts/build-all.sh android debug

# 构建所有 Windows 平台 (Debug模式)
./scripts/build-all.sh windows debug
```

## 手动构建

如果需要更精细的控制，可以手动运行 Meson 命令：

```bash
# 配置构建 (以 Linux x86_64 为例)
meson setup build-linux-x86_64 --cross-file=cross-files/linux-x86_64.ini

# 编译
meson compile -C build-linux-x86_64

# 配置 iOS 设备构建
meson setup build-ios-arm64 \
    --cross-file=cross-files/ios-arm64.ini \
    -Dios_sdk=iphoneos \
    -Dios_deployment_target=12.0

# 编译 iOS
meson compile -C build-ios-arm64

# 配置 Android ARM64 构建
export ANDROID_NDK_ROOT=/path/to/ndk
meson setup build-android-arm64 \
    --cross-file=cross-files/android-arm64.ini \
    -Dandroid_build=true \
    -Dandroid_abi=arm64-v8a

# 编译 Android
meson compile -C build-android-arm64
```

## 构建选项

在 `meson_options.txt` 中定义了以下选项：

- `android_build`: 是否为 Android 平台构建 (boolean)
- `android_abi`: Android ABI 类型 (arm64-v8a, armeabi-v7a, x86_64, x86)
- `android_ndk_root`: Android NDK 根目录路径
- `ios_sdk`: iOS SDK 类型 (iphoneos, iphonesimulator)
- `ios_deployment_target`: iOS 最小部署目标 (默认: 12.0)
- `ios_codesign_identity`: iOS 代码签名身份
- `macos_codesign_identity`: macOS 代码签名身份
- `mingw_prefix`: MinGW 工具链前缀

使用示例：
```bash
# Android 构建
meson setup build-dir --cross-file=cross-files/android-arm64.ini \
    -Dandroid_build=true \
    -Dandroid_abi=arm64-v8a

# iOS 构建
meson setup build-dir --cross-file=cross-files/ios-arm64.ini \
    -Dios_sdk=iphoneos \
    -Dios_deployment_target=12.0
```

## 输出文件

构建完成后，库文件将被复制到以下位置：

```
../Plugins/lib/
├── windows/
│   ├── x86_64/gilzoide-sqlite-net.dll
│   ├── x86/gilzoide-sqlite-net.dll
│   └── arm64/gilzoide-sqlite-net.dll
├── linux/
│   └── x86_64/libgilzoide-sqlite-net.so
├── macos/
│   └── libgilzoide-sqlite-net.dylib
├── ios/
│   └── libgilzoide-sqlite-net.a        # iOS 静态库 (ARM64)
└── android/
    ├── arm64/libgilzoide-sqlite-net.so
    ├── arm32/libgilzoide-sqlite-net.so
    ├── x86_64/libgilzoide-sqlite-net.so
    └── x86/libgilzoide-sqlite-net.so
```

## 故障排除

### 1. Android NDK 问题
确保设置了 `ANDROID_NDK_ROOT` 环境变量：
```bash
export ANDROID_NDK_ROOT=/path/to/your/android-ndk
```

### 2. MinGW 工具链问题
确保安装了完整的 MinGW-w64 工具链：
```bash
# 检查工具链是否可用
x86_64-w64-mingw32-gcc --version
i686-w64-mingw32-gcc --version
aarch64-w64-mingw32-gcc --version
```

### 3. iOS 构建问题
确保 Xcode 和 iOS SDK 已正确安装：
```bash
# 检查 Xcode 命令行工具
xcode-select --version

# 检查 iOS SDK
xcrun --sdk iphoneos --show-sdk-path
xcrun --sdk iphonesimulator --show-sdk-path
```

### 4. macOS/iOS 代码签名
如果需要代码签名，设置签名身份：
```bash
# macOS 代码签名
meson setup build-macos --cross-file=cross-files/macos-universal.ini \
    -Dmacos_codesign_identity="Developer ID Application: Your Name"

# iOS 代码签名
meson setup build-ios --cross-file=cross-files/ios-arm64.ini \
    -Dios_codesign_identity="iPhone Developer"
```

### 5. 清理构建
```bash
# 清理所有构建目录
rm -rf build-*
```

## 与原 Makefile 的对比

| 功能 | Makefile | Meson |
|------|----------|--------|
| 构建速度 | 较慢 | 更快 (Ninja) |
| 依赖管理 | 手动 | 自动 |
| 交叉编译 | 手动配置 | 标准化配置文件 |
| 并行构建 | 有限支持 | 完全并行 |
| IDE 集成 | 无 | 支持多种 IDE |
| 配置缓存 | 无 | 自动缓存 |

## 脚本详细说明

`scripts/` 目录包含了所有构建和配置相关的脚本。以下是各脚本的详细说明：

### 构建脚本

#### `build-platform.sh` - 单平台构建
**用途**: 构建指定单个平台的SQLCipher库
**语法**: `./build-platform.sh <platform> [build_type]`
**参数**:
- `platform`: 目标平台 (linux-x86_64, windows-x86_64, ios-arm64, android-arm64 等)
- `build_type`: 构建类型，可选 (release/debug，默认：release)

**使用示例**:
```bash
# 构建iOS ARM64版本
./build-platform.sh ios-arm64

# 构建Windows x86_64 Debug版本
./build-platform.sh windows-x86_64 debug

# 构建Android ARM64版本
./build-platform.sh android-arm64
```

**依赖关系**: 
- 依赖: `check-env.sh` (可选，用于环境检查)
- 依赖: 对应平台的交叉编译工具链
- 被依赖: `build-all.sh`

#### `build-all.sh` - 批量构建
**用途**: 批量构建多个平台的SQLCipher库
**语法**: `./build-all.sh [platform_filter] [build_type]`
**参数**:
- `platform_filter`: 平台过滤器，可选 (ios/android/windows/linux，默认：全部)
- `build_type`: 构建类型，可选 (release/debug，默认：release)

**使用示例**:
```bash
# 构建所有平台
./build-all.sh

# 只构建iOS相关平台
./build-all.sh ios

# 构建所有Android平台的Debug版本
./build-all.sh android debug

# 构建所有Windows平台
./build-all.sh windows
```

**依赖关系**:
- 依赖: `build-platform.sh`

#### ~~`create-ios-framework.sh`~~ - iOS Framework打包（已废弃）
**状态**: ⚠️ **已废弃** - iOS不允许Unity使用动态库
**原因**: Unity在iOS平台只支持静态库（.a文件），不支持Framework（动态库）
**替代方案**: 直接使用`build-platform.sh`生成的静态库文件

### 环境配置脚本

#### `check-env.sh` - 环境检查
**用途**: 检查构建环境是否完备，自动安装缺失的依赖
**语法**: `./check-env.sh [platform]`
**参数**:
- `platform`: 要检查的特定平台，可选 (不指定则检查所有)

**功能**:
- 🔍 检查基础构建工具 (meson, ninja, build-essential)
- 🔍 检查交叉编译工具链 (mingw, Android NDK, Xcode)
- 📦 自动提示安装命令
- ⚙️ 自动设置环境变量
- 🖥️ 支持 Linux 和 macOS 系统
- ⚠️ 提供Windows ARM64限制说明

**使用示例**:
```bash
# 检查所有平台的构建环境
./check-env.sh

# 只检查Android构建环境
./check-env.sh android

# 只检查iOS构建环境  
./check-env.sh ios
```

**依赖关系**:
- 无依赖
- 被依赖: 推荐在所有构建前运行

#### `clean-builds.sh` - 清理构建
**用途**: 清理构建目录和产物，释放磁盘空间
**语法**: `./clean-builds.sh [options]`

**功能**:
- 🧹 清理所有 `build-*` 目录
- 🧹 清理生成的库文件
- 🧹 清理临时文件
- 📊 显示清理前后的磁盘使用情况
- ⚠️ 支持交互式确认模式

**使用示例**:
```bash
# 清理所有构建文件
./clean-builds.sh

# 静默清理（不询问确认）
./clean-builds.sh --force
```

**依赖关系**:
- 无依赖
- 与所有构建脚本无冲突

### 符号处理脚本

#### `apply_prefix.sh` - 符号前缀应用
**用途**: 为SQLite函数添加`cr_`前缀，避免符号冲突
**语法**: `./apply_prefix.sh`

**功能**:
- 🔧 修改`sqlite3.c`和`sqlite3.h`中的函数名
- 🔧 同步更新C# DllImport中的EntryPoint
- 🔄 幂等操作，可安全重复运行
- ✅ 处理52个Unity需要的SQLite函数

**使用示例**:
```bash
# 应用cr_前缀到SQLite函数
./apply_prefix.sh
```

**依赖关系**:
- 依赖: `add_cr_prefix_fixed.sed`, `add_cr_prefix_csharp.sed`
- 被依赖: 在构建前需要执行以避免符号冲突

#### `extract-unity-symbols.sh` - Unity符号提取
**用途**: 从构建产物中提取Unity需要的符号列表
**语法**: `./extract-unity-symbols.sh [platform]`

**功能**:
- 🔍 分析构建后的静态库
- 📋 提取实际导出的符号
- ✅ 验证与`unity_symbols_exports.txt`的一致性
- 📊 生成符号报告

**使用示例**:
```bash
# 提取iOS平台的符号
./extract-unity-symbols.sh ios-arm64

# 提取所有平台的符号
./extract-unity-symbols.sh
```

**依赖关系**:
- 依赖: 对应平台的构建产物
- 依赖: `unity_required_symbols.txt`

#### `merge-static-libs.sh` - 静态库合并
**用途**: 合并SQLCipher和OpenSSL静态库，隐藏OpenSSL符号
**语法**: `./merge-static-libs.sh <input_lib> <output_lib>`

**功能**:
- 🔗 合并多个静态库为单一库文件
- 🔒 隐藏OpenSSL符号，只导出SQLite符号
- 📊 符号统计和验证
- ✅ 确保Unity所需的50+个符号正确导出

**使用示例**:
```bash
# 合并iOS静态库
./merge-static-libs.sh build-ios-arm64/libsqlcipher.a ../Plugins/lib/ios/libgilzoide-sqlite-net.a
```

**依赖关系**:
- 依赖: `unity_symbols_exports.txt`
- 被依赖: `build-platform.sh` (自动调用)

### 配置文件

#### `unity_required_symbols.txt` - Unity需要的符号列表
**用途**: 定义Unity SQLCipher.NET需要的52个SQLite函数
**格式**: 每行一个函数名（原始名称，不含前缀）
```
sqlite3_threadsafe
sqlite3_open
sqlite3_close
...
```

#### `unity_symbols_exports.txt` - 导出符号列表
**用途**: 定义实际导出的符号列表（包含平台前缀）
**格式**: 每行一个符号名（包含下划线前缀和cr_前缀）
```
_cr_sqlite3_threadsafe
_cr_sqlite3_open
_cr_sqlite3_close
...
```

#### `add_cr_prefix_fixed.sed` - SQLite函数前缀处理
**用途**: 幂等的sed脚本，为SQLite函数添加`cr_`前缀
**特点**:
- ✅ 幂等操作，可安全重复运行
- ✅ 处理所有上下文（函数声明、调用、宏定义等）
- ✅ 自动修复双重前缀问题

#### `add_cr_prefix_csharp.sed` - C# DllImport处理
**用途**: 同步更新C#代码中的DllImport EntryPoint
**功能**: 将`EntryPoint = "sqlite3_xxx"`替换为`EntryPoint = "cr_sqlite3_xxx"`

### 脚本依赖关系图

```
check-env.sh (推荐首先运行)
    ↓
apply_prefix.sh (构建前运行)
    ↓
build-platform.sh ────→ build-all.sh
    ↓                        ↓
merge-static-libs.sh         ↓
    ↓                        ↓
extract-unity-symbols.sh     ↓
                             ↓
clean-builds.sh (可选，清理时使用)
```

### 最佳实践工作流

```bash
# 1. 环境检查（首次运行或切换开发环境时）
./scripts/check-env.sh

# 2. 应用符号前缀（避免冲突）
./scripts/apply_prefix.sh

# 3. 构建目标平台
./scripts/build-platform.sh ios-arm64

# 或者批量构建
./scripts/build-all.sh

# 4. 验证符号导出（可选）
./scripts/extract-unity-symbols.sh ios-arm64

# 5. 清理构建文件（可选）
./scripts/clean-builds.sh
```

## 贡献

如需添加新平台支持或改进构建配置，请：

1. 在 `cross-files/` 目录添加新的交叉编译文件
2. 更新 `meson.build` 中的平台检测逻辑
3. 更新构建脚本中的平台列表
4. 测试构建是否正常工作

## 平台限制

### Windows ARM64 支持

由于大多数Linux发行版（包括Ubuntu 24.04）不提供ARM64 MinGW工具链，`windows-arm64`目标有以下限制：

**可用选项：**
1. **Docker方案 (推荐)**:
   ```bash
   docker run --rm -v $(pwd):/workspace dockcross/windows-arm64 \
     bash -c "cd /workspace && ./build-platform.sh windows-arm64"
   ```

2. **CI/CD方案**:
   - GitHub Actions with custom runners  
   - 使用专门的交叉编译环境

3. **原生Windows环境**:
   - Visual Studio with Windows SDK
   - LLVM/Clang with Windows ARM64 target

**环境检查脚本会自动检测并提供详细的替代方案说明。**

### 构建结果

成功构建后，库文件将位于：
- Windows x86_64: `Plugins/lib/windows/x86_64/gilzoide-sqlite-net.dll`
- Windows x86: `Plugins/lib/windows/x86/gilzoide-sqlite-net.dll`  
- Linux x86_64: `Plugins/lib/linux/x86_64/libgilzoide-sqlite-net.so`
- macOS Universal: `Plugins/lib/macos/libgilzoide-sqlite-net.dylib`
- iOS: `Plugins/lib/ios/libgilzoide-sqlite-net.a` (ARM64静态库，支持iOS 12+)
- Android: `Plugins/lib/android/{arm64,arm32,x86_64,x86}/libgilzoide-sqlite-net.so`

**iOS 静态库特点**：
- ✅ 标准静态库格式，符合Unity iOS构建要求
- ✅ OpenSSL 3.0.8静态链接，符号完全隐藏
- ✅ 支持iOS 12.0+，覆盖主流设备
- ✅ 只导出Unity需要的SQLite函数，避免符号冲突