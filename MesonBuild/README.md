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
| Android | ARM64, ARM32, x86_64, x86 | Android NDK | ✅ 完全支持 |

**\* Windows ARM64 限制说明**: 大多数Linux发行版不提供ARM64 MinGW工具链，可使用Docker或CI/CD方案。

## 主要特性

- ✅ **SQLCipher 加密支持**：使用 OpenSSL 3.0.8 作为加密后端
- ✅ **静态链接 OpenSSL**：避免版本冲突，确保可移植性
- ✅ **符号隐藏**：OpenSSL 符号完全隐藏，防止与其他库冲突
- ✅ **16KB 对齐支持**：Android 平台自动配置 16KB 页面对齐
- ✅ **多平台交叉编译**：支持 Windows、Linux、macOS、Android
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

# 构建 Android ARM64
./scripts/build-platform.sh android-arm64
```

#### 批量构建
```bash
# 构建所有平台
./scripts/build-all.sh

# 构建所有 Android 平台
./scripts/build-all.sh release android

# 构建所有 Windows 平台 (Debug 模式)
./scripts/build-all.sh debug windows
```

## 手动构建

如果需要更精细的控制，可以手动运行 Meson 命令：

```bash
# 配置构建 (以 Linux x86_64 为例)
meson setup build-linux-x86_64 --cross-file=cross-files/linux-x86_64.ini

# 编译
meson compile -C build-linux-x86_64

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
- `macos_codesign_identity`: macOS 代码签名身份
- `mingw_prefix`: MinGW 工具链前缀

使用示例：
```bash
meson setup build-dir --cross-file=cross-files/android-arm64.ini \
    -Dandroid_build=true \
    -Dandroid_abi=arm64-v8a
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

### 3. macOS 代码签名
如果需要代码签名，设置签名身份：
```bash
meson setup build-macos --cross-file=cross-files/macos-universal.ini \
    -Dmacos_codesign_identity="Developer ID Application: Your Name"
```

### 4. 清理构建
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
- Android: `Plugins/lib/android/{arm64,arm32,x86_64,x86}/libgilzoide-sqlite-net.so`