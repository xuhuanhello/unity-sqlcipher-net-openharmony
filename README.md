# SQLCipher-net for Unity with OpenHarmony Support

[中文版本 / Chinese Version](#中文版本)

> **Enhanced version based on [gilzoide/unity-sqlite-net](https://github.com/gilzoide/unity-sqlite-net)**
> 
> This project builds upon the excellent foundation provided by the original author, adding SQLCipher encryption support, Meson build system, and OpenHarmony platform support.

[![openupm](https://img.shields.io/npm/v/com.gilzoide.sqlite-net?label=openupm&registry_uri=https://package.openupm.com)](https://openupm.com/packages/com.gilzoide.sqlite-net/)

This package provides the excellent [SQLite-net](https://github.com/praeclarum/sqlite-net) library with **SQLCipher encryption support** for accessing encrypted SQLite databases in Unity, including **OpenHarmony platform support**.

## 🆕 Key Enhancements

### ✅ SQLCipher Encryption Support
- Complete database encryption functionality
- Compatible with SQLCipher 4.x API
- Transparent encryption/decryption operations

### ✅ Meson Build System
- Replaced original CMake build system
- Better cross-platform support
- Unified build configuration

### ✅ OpenHarmony Platform Support
- Support for HarmonyOS ARM64 architecture
- Automated SDK detection and installation
- Complete cross-compilation support

### ✅ Enhanced Symbol Management
- Added `cr_` prefix to all DllImport declarations
- Prevents conflicts with system SQLite on iOS platform
- Ensures proper library binding across all platforms

### ✅ Extended SQLite Features
- **New modules**: [FTS4](https://sqlite.org/fts3.html), [JSON1](https://sqlite.org/json1.html), [Soundex](https://sqlite.org/lang_corefunc.html#soundex) support
- **Enhanced configuration**: Column metadata, hidden columns, foreign keys enabled by default
- **Thread safety**: Improved thread-safe operations with proper memory management

## Features

- [SQLite-net v1.9.172](https://github.com/praeclarum/sqlite-net/tree/v1.9.172)
  + Both synchronous and asynchronous APIs are available
  + **SQLCipher encryption/decryption support**
  + `SQLiteConnection.Serialize` extension method for serializing a database to `byte[]`
  + `SQLiteConnection.Deserialize` extension method for deserializing memory into an open database
- [SQLCipher 4.10.0](https://github.com/sqlcipher/sqlcipher) with [SQLite 3.50.4](https://sqlite.org/releaselog/3_50_4.html)
  + Database encryption and decryption with OpenSSL backend
  + Enabled modules: [R\*Tree](https://sqlite.org/rtree.html), [Geopoly](https://sqlite.org/geopoly.html), [FTS4](https://sqlite.org/fts3.html), [FTS5](https://sqlite.org/fts5.html), [JSON1](https://sqlite.org/json1.html), [Built-In Math Functions](https://www.sqlite.org/lang_mathfunc.html), [Soundex](https://sqlite.org/lang_corefunc.html#soundex)
  + Thread-safe with foreign key support enabled by default
  + Column metadata and hidden columns support
  + Supports Windows, Linux, macOS, Android, iOS, tvOS, visionOS and **OpenHarmony** platforms
  + WebGL support is not yet available in this SQLCipher version

## 🚀 Quick Start

### Environment Check
```bash
cd MesonBuild~
./scripts/check-env.sh
```

### Build All Platforms
```bash
./scripts/build-all.sh
```

### Build Specific Platform
```bash
# OpenHarmony ARM64
./scripts/build-platform.sh harmony-arm64 release

# Android ARM64
./scripts/build-platform.sh android-arm64 release

# Other platforms...
```

## Usage Example

The following code demonstrates SQLCipher encryption functionality:

```cs
using SQLite;
using UnityEngine;

public class Player
{
    [PrimaryKey, AutoIncrement]
    public int Id { get; set; }
    public string Name { get; set; }
}

public class TestSQLCipher : MonoBehaviour
{
    void Start()
    {
        // 1. Create an encrypted connection to the database
        var db = new SQLiteConnection($"{Application.persistentDataPath}/MyEncryptedDb.db", 
            SQLiteOpenFlags.ReadWrite | SQLiteOpenFlags.Create, 
            storeDateTimeAsTicks: false, 
            key: "your-encryption-password");

        // 2. The rest of the API is identical to SQLite-net
        db.CreateTable<Player>();
        
        var newPlayer = new Player { Name = "encrypted_user" };
        db.Insert(newPlayer);
        
        var players = db.Table<Player>().ToList();
        foreach (Player player in players)
        {
            Debug.Log($"Found encrypted player: {player.Name}");
        }
    }
}
```

## 📦 Supported Platforms

| Platform | Architecture | Status |
|----------|--------------|--------|
| **OpenHarmony** | ARM64 | ✅ New Support |
| Android | ARM32/ARM64/x86/x86_64 | ✅ |
| iOS | ARM64/Simulator | ✅ |
| macOS | Universal | ✅ |
| Windows | x86/x86_64/ARM64 | ✅ |
| Linux | x86_64 | ✅ |
| WebGL | - | ❌ Not yet supported |

## 🔧 Build System

This project uses **Meson Build System** instead of the original build approach:

- **Unified Configuration**: All platforms use the same build configuration
- **Cross-Compilation**: Support building target platforms from any host
- **Dependency Management**: Automatic handling of OpenSSL and other dependencies
- **Docker Support**: Containerized build environments available

For detailed build documentation, see: [MesonBuild~/README.md](MesonBuild~/README.md)

## 🌿 Branch Information

- **`mesonbuild`** (default branch): Main development branch with all new features and improvements, including OpenHarmony platform support
- **`main`**: Preserves original project structure for comparison and reference
- Recommended to use `mesonbuild` branch for development and usage

## 📄 License

This project maintains the same MIT license as the original project.

**Original Project**:
- Original Author: [gilzoide](https://github.com/gilzoide)
- Original Project: [unity-sqlite-net](https://github.com/gilzoide/unity-sqlite-net)
- License: [MIT license](LICENSE.txt)

**Third-party Code**:
- SQLite-net: [MIT license](Runtime/sqlite-net/LICENSE.txt)
- SQLCipher: [BSD license](https://github.com/sqlcipher/sqlcipher/blob/master/LICENSE.md)
- SQLite: [public domain](https://sqlite.org/copyright.html)
- OpenSSL: [Apache 2.0 license](https://www.openssl.org/source/license.html)

## 🙏 Acknowledgments

Thanks to the original author [gilzoide](https://github.com/gilzoide) for providing an excellent foundation project. This project builds upon their work with the following major improvements:

1. **SQLCipher Integration**: Added complete database encryption support
2. **Meson Build System**: Restructured the entire build system for better cross-platform support
3. **OpenHarmony Support**: Added comprehensive support for the HarmonyOS platform
4. **Enhanced Symbol Management**: Added `cr_` prefix to prevent iOS system library conflicts

## Modifications Made to Original Project

### Build System Changes
- Replaced CMake with **Meson build system**
- Added comprehensive cross-compilation support
- Integrated automated dependency management
- Added Docker-based build environments

### SQLCipher Integration
- Replaced SQLite with **SQLCipher for encryption support**
- Added OpenSSL dependency management
- Configured encryption-specific build flags
- Maintained API compatibility with SQLite-net

### Platform Support
- Added **OpenHarmony (HarmonyOS) ARM64 support**
- Enhanced Android build configuration
- Improved iOS/macOS universal binary support
- Updated Windows ARM64 support

### Symbol Management
- **Added `cr_` prefix to all DllImport declarations**
- Prevents conflicts with system SQLite libraries on iOS
- Ensures proper library binding across all platforms
- Modified symbol export scripts for consistent naming

### Infrastructure Improvements
- Added automated environment checking scripts
- Implemented intelligent SDK detection and installation
- Created platform-specific build orchestration
- Added comprehensive error handling and user guidance

---

# 中文版本

## 🆕 主要增强功能

### ✅ SQLCipher 加密支持
- 完整的数据库加密功能
- 兼容 SQLCipher 4.x API
- 透明的加密/解密操作

### ✅ Meson 构建系统
- 替换原有的 CMake 构建
- 更好的跨平台支持
- 统一的构建配置

### ✅ OpenHarmony 平台支持
- 支持 HarmonyOS ARM64 架构
- 自动化 SDK 检测和安装
- 完整的交叉编译支持

### ✅ 增强的符号管理
- 为所有 DllImport 声明添加了 `cr_` 前缀
- 防止在 iOS 平台与系统 SQLite 库冲突
- 确保所有平台的正确库绑定

### ✅ 扩展的 SQLite 功能
- **新增模块**：[FTS4](https://sqlite.org/fts3.html)、[JSON1](https://sqlite.org/json1.html)、[Soundex](https://sqlite.org/lang_corefunc.html#soundex) 支持
- **增强配置**：列元数据、隐藏列、默认启用外键支持
- **线程安全**：改进的线程安全操作和内存管理

## 功能特性

- [SQLite-net v1.9.172](https://github.com/praeclarum/sqlite-net/tree/v1.9.172)
  + 同时提供同步和异步 API
  + **SQLCipher 加密/解密支持**
  + `SQLiteConnection.Serialize` 扩展方法，用于将数据库序列化为 `byte[]`
  + `SQLiteConnection.Deserialize` 扩展方法，用于将内存数据反序列化到数据库
- [SQLCipher 4.10.0](https://github.com/sqlcipher/sqlcipher) 基于 [SQLite 3.50.4](https://sqlite.org/releaselog/3_50_4.html)
  + 基于 OpenSSL 后端的数据库加密和解密功能
  + 启用模块：[R\*Tree](https://sqlite.org/rtree.html)、[Geopoly](https://sqlite.org/geopoly.html)、[FTS4](https://sqlite.org/fts3.html)、[FTS5](https://sqlite.org/fts5.html)、[JSON1](https://sqlite.org/json1.html)、[内置数学函数](https://www.sqlite.org/lang_mathfunc.html)、[Soundex](https://sqlite.org/lang_corefunc.html#soundex)
  + 线程安全，默认启用外键支持
  + 支持列元数据和隐藏列
  + 支持 Windows、Linux、macOS、Android、iOS、tvOS、visionOS 和 **OpenHarmony** 平台
  + WebGL 平台暂未支持此 SQLCipher 版本

## 🚀 快速开始

### 环境检查
```bash
cd MesonBuild~
./scripts/check-env.sh
```

### 构建所有平台
```bash
./scripts/build-all.sh
```

### 构建特定平台
```bash
# OpenHarmony ARM64
./scripts/build-platform.sh harmony-arm64 release

# Android ARM64
./scripts/build-platform.sh android-arm64 release

# 其他平台...
```

## 使用示例

以下代码演示了 SQLCipher 加密功能：

```cs
using SQLite;
using UnityEngine;

public class Player
{
    [PrimaryKey, AutoIncrement]
    public int Id { get; set; }
    public string Name { get; set; }
}

public class TestSQLCipher : MonoBehaviour
{
    void Start()
    {
        // 1. Create an encrypted connection to the database
        var db = new SQLiteConnection($"{Application.persistentDataPath}/MyEncryptedDb.db", 
            SQLiteOpenFlags.ReadWrite | SQLiteOpenFlags.Create, 
            storeDateTimeAsTicks: false, 
            key: "your-encryption-password");

        // 2. The rest of the API is identical to SQLite-net
        db.CreateTable<Player>();
        
        var newPlayer = new Player { Name = "encrypted_user" };
        db.Insert(newPlayer);
        
        var players = db.Table<Player>().ToList();
        foreach (Player player in players)
        {
            Debug.Log($"Found encrypted player: {player.Name}");
        }
    }
}
```

## 📦 支持的平台

| 平台 | 架构 | 状态 |
|------|------|------|
| **OpenHarmony** | ARM64 | ✅ 新增支持 |
| Android | ARM32/ARM64/x86/x86_64 | ✅ |
| iOS | ARM64/Simulator | ✅ |
| macOS | Universal | ✅ |
| Windows | x86/x86_64/ARM64 | ✅ |
| Linux | x86_64 | ✅ |
| WebGL | - | ❌ 暂未支持 |

## 🔧 构建系统

本项目使用 **Meson 构建系统**替代原有的构建方式：

- **统一配置**：所有平台使用相同的构建配置
- **交叉编译**：支持从任意主机构建目标平台
- **依赖管理**：自动处理 OpenSSL 等依赖
- **Docker 支持**：提供容器化构建环境

详细构建文档请参考：[MesonBuild~/README.md](MesonBuild~/README.md)

## 📄 License

本项目基于原作者的 MIT 许可证，保持相同的开源协议。

**原始项目**：
- 原作者：[gilzoide](https://github.com/gilzoide)
- 原项目：[unity-sqlite-net](https://github.com/gilzoide/unity-sqlite-net)
- 许可证：[MIT license](LICENSE.txt)

**第三方代码**：
- SQLite-net: [MIT license](Runtime/sqlite-net/LICENSE.txt)
- SQLCipher: [BSD license](https://github.com/sqlcipher/sqlcipher/blob/master/LICENSE.md)
- SQLite: [public domain](https://sqlite.org/copyright.html)
- OpenSSL: [Apache 2.0 license](https://www.openssl.org/source/license.html)

## 🌿 分支说明

- **`mesonbuild`** (默认分支)：主要开发分支，包含所有新功能和改进，包括 OpenHarmony 平台支持
- **`main`**：保留原始项目结构，用于对比和参考
- 建议使用 `mesonbuild` 分支进行开发和使用

## 🙏 致谢

感谢原作者 [gilzoide](https://github.com/gilzoide) 提供的优秀基础项目。本项目在其基础上进行了以下主要改进：

1. **SQLCipher 集成**：添加了完整的数据库加密支持
2. **Meson 构建**：重构了整个构建系统，提供更好的跨平台支持
3. **OpenHarmony 支持**：新增了 HarmonyOS 平台的完整支持

## Modifications made to original project

### Build System Changes
- Replaced CMake with **Meson build system**
- Added comprehensive cross-compilation support
- Integrated automated dependency management
- Added Docker-based build environments

### SQLCipher Integration
- Replaced SQLite with **SQLCipher for encryption support**
- Added OpenSSL dependency management
- Configured encryption-specific build flags
- Maintained API compatibility with SQLite-net

### Platform Support
- Added **OpenHarmony (HarmonyOS) ARM64 support**
- Enhanced Android build configuration
- Improved iOS/macOS universal binary support
- Updated Windows ARM64 support

### Infrastructure Improvements
- Added automated environment checking scripts
- Implemented intelligent SDK detection and installation
- Created platform-specific build orchestration
- Added comprehensive error handling and user guidance