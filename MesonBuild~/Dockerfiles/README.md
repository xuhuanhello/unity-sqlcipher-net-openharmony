# Docker 构建环境

本目录包含用于跨平台构建 Unity SQLCipher 的 Docker 配置文件。

## 支持的平台

- **Android**: 所有 Android 架构 (ARM64, ARM32, x86_64, x86)
- **Windows**: Windows 交叉编译 (x86_64, x86, ARM64*)
- **Linux**: Linux 原生构建 (x86_64)

*注：ARM64 MinGW 工具链的可用性取决于基础镜像的发行版版本

## Dockerfile 说明

### Dockerfile.android
- 基于 Debian 12
- 包含 Android NDK r26c
- 支持所有 Android 架构的交叉编译

### Dockerfile.linux
- 基于 Debian 12
- 包含标准 GCC 工具链
- 用于 Linux x86_64 原生构建

### Dockerfile.windows
- 基于 Debian 12
- 包含 MinGW-w64 交叉编译工具链
- 支持 Windows x86_64 和 x86
- 尝试安装 ARM64 工具链（如果可用）

## 使用方法

### 单平台构建
```bash
# Windows 64位
./scripts/build-platform.sh windows-x86_64-docker release

# Android ARM64
./scripts/build-platform.sh android-arm64-docker release

# Linux 64位
./scripts/build-platform.sh linux-x86_64-docker release
```

### 批量构建
```bash
# 构建所有 Docker 支持的平台
./scripts/build-all.sh all-docker release

# 只构建 Android 平台
./scripts/build-all.sh android-docker release

# 只构建 Windows 平台
./scripts/build-all.sh windows-docker release
```

## 优势

1. **环境一致性**: 所有开发者使用相同的构建环境
2. **跨平台支持**: 在 macOS 上构建 Windows 和 Linux 目标
3. **简化依赖管理**: 无需在主机上安装复杂的交叉编译工具链
4. **隔离性**: 构建环境与主机系统隔离，避免冲突

## 前置条件

1. 安装 Docker
   ```bash
   # 检查和安装 Docker
   ./scripts/check-env.sh
   ```

2. 启动 Docker 服务
   - macOS: 启动 Docker Desktop
   - Linux: `sudo systemctl start docker`

## 构建流程

1. **镜像构建**: 首次运行时会自动构建相应的 Docker 镜像
2. **容器运行**: 在容器中挂载项目目录并执行构建
3. **结果输出**: 构建产物保存到 `../Plugins/lib/` 目录

## 注意事项

- 首次构建会下载基础镜像和安装工具链，可能需要较长时间
- 镜像会被缓存，后续构建会更快
- 构建产物在容器外部可见，无需额外导出步骤
- 如果需要清理 Docker 镜像，可使用 `docker image prune` 命令

## 故障排除

### Docker 服务未运行
```bash
# Linux
sudo systemctl start docker

# macOS
open -a Docker
```

### 权限问题 (Linux)
```bash
# 将用户添加到 docker 组
sudo usermod -aG docker $USER
# 重新登录或执行
newgrp docker
```

### 镜像构建失败
```bash
# 清理失败的镜像和容器
docker system prune -f
# 重新尝试构建
```

### 网络问题
如果在中国大陆使用，可能需要配置 Docker 镜像源以加速下载。
