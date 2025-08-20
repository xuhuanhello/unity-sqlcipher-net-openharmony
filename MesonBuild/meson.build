project('unity-sqlcipher-net', 'c',
  version : '1.0.0',
  default_options : [
    'warning_level=1',
    'c_std=gnu99',  # 使用 GNU C99 支持汇编语法
    'default_library=static'  # 强制 OpenSSL 为静态库
  ]
)

# 构建选项
sqlite_debug = get_option('debug')

# OpenSSL 依赖 (强制使用指定的 3.0.8 版本，不检查系统版本)
openssl_subproject = subproject('openssl')
openssl_dep = openssl_subproject.get_variable('libcrypto_dep')

# 源文件路径 (现在应该是 SQLCipher 源码)
sqlite_src = '../Plugins/sqlite-amalgamation/sqlite3.c'

# SQLCipher 编译定义
sqlcipher_c_args = [
  # SQLCipher 核心配置
  '-DSQLITE_HAS_CODEC=1',                              # 启用加密支持
  '-DSQLCIPHER_CRYPTO_OPENSSL=1',                      # 使用 OpenSSL 作为加密后端
  '-DSQLITE_EXTRA_INIT=sqlcipher_extra_init',          # SQLCipher 必需的初始化函数
  '-DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown',  # SQLCipher 必需的关闭函数
  
  # 基础配置
  '-DSQLITE_THREADSAFE=1',             # 线程安全
  '-DSQLITE_TEMP_STORE=2',             # 临时数据存储在内存
  '-DSQLITE_SOUNDEX=1',                # 启用 Soundex 支持
  '-DSQLITE_DEFAULT_FOREIGN_KEYS=1',   # 默认启用外键
  '-DSQLITE_MAX_ATTACHED=10',          # 最大附加数据库数量
  
  # 功能扩展（避免与 OMIT 选项冲突）
  '-DSQLITE_ENABLE_RTREE=1',           # 启用 R-tree 支持
  '-DSQLITE_ENABLE_FTS4=1',            # 启用全文搜索 FTS4
  '-DSQLITE_ENABLE_FTS5=1',            # 启用全文搜索 FTS5
  '-DSQLITE_ENABLE_JSON1=1',           # 启用 JSON 支持
  '-DSQLITE_ENABLE_GEOPOLY=1',         # 启用地理多边形支持
  
  # 类型支持
  '-D_GNU_SOURCE',                     # 启用 GNU 扩展，包含完整的类型定义
  '-include', 'stdint.h',              # 强制包含 stdint.h 头文件
]

# 符号隐藏配置 (防止 OpenSSL 符号冲突)
symbol_hiding_args = []
symbol_export_files = []

if host_machine.system() == 'windows'
  # Windows 使用 .def 文件控制符号导出
  symbol_hiding_args += ['/DEF:' + meson.current_source_dir() + '/exports.def']
  symbol_export_files += [meson.current_source_dir() + '/exports.def']
else
  # Unix-like 系统使用版本脚本隐藏符号
  symbol_hiding_args += ['-Wl,--version-script=' + meson.current_source_dir() + '/exports.map']
  symbol_export_files += [meson.current_source_dir() + '/exports.map']
endif

# 基础编译参数
base_c_args = sqlcipher_c_args
base_link_args = symbol_hiding_args

# Debug/Release 配置
if sqlite_debug
  base_c_args += ['-O0', '-g', '-DDEBUG']
else
  base_c_args += ['-O3', '-DNDEBUG']
endif

# 获取目标平台信息
host_system = host_machine.system()
host_cpu = host_machine.cpu_family()

# 平台特定配置
platform_c_args = base_c_args
platform_link_args = base_link_args
library_name = 'gilzoide-sqlite-net'
library_suffix = ''
install_dir = ''

# Windows 配置
if host_system == 'windows'
  platform_link_args += ['-shared']
  library_suffix = '.dll'
  if host_cpu == 'x86_64'
    install_dir = '../Plugins/lib/windows/x86_64'
  elif host_cpu == 'x86'
    install_dir = '../Plugins/lib/windows/x86'
  elif host_cpu == 'aarch64'
    install_dir = '../Plugins/lib/windows/arm64'
  endif

# Linux 配置
elif host_system == 'linux'
  platform_c_args += ['-fPIC']
  platform_link_args += ['-shared', '-lm', '-Wl,-Bsymbolic']
  # 保持默认名称，Meson 会自动添加 'lib' 前缀
  library_suffix = '.so'
  if host_cpu == 'x86_64'
    install_dir = '../Plugins/lib/linux/x86_64'
  endif

# macOS 配置
elif host_system == 'darwin'
  # Universal binary (arm64 + x86_64)
  platform_c_args += ['-arch', 'arm64', '-arch', 'x86_64']
  platform_link_args += ['-shared', '-arch', 'arm64', '-arch', 'x86_64']
  # 保持默认名称，Meson 会自动添加 'lib' 前缀
  library_suffix = '.dylib'
  install_dir = '../Plugins/lib/macos'

# Android 配置 (通过交叉编译文件处理)
elif host_system.contains('android') or get_option('android_build')
  platform_c_args += ['-fPIC']
  platform_link_args += ['-shared', '-lm', '-llog', '-Wl,-z,max-page-size=16384']  # 添加 -llog
  # 保持默认名称，Meson 会自动添加 'lib' 前缀
  library_suffix = '.so'
  
  android_abi = get_option('android_abi')
  if android_abi == 'arm64-v8a'
    install_dir = '../Plugins/lib/android/arm64'
  elif android_abi == 'armeabi-v7a'
    install_dir = '../Plugins/lib/android/arm32'
  elif android_abi == 'x86_64'
    install_dir = '../Plugins/lib/android/x86_64'
  elif android_abi == 'x86'
    install_dir = '../Plugins/lib/android/x86'
  endif
endif

# 确保输出目录存在
if install_dir != ''
  run_command('mkdir', '-p', install_dir, check: false)
endif

# 构建动态库
library_sources = [sqlite_src]
if host_machine.system() == 'windows' and symbol_export_files.length() > 0
  # Windows 平台需要将 .def 文件作为源文件传递
  library_sources += symbol_export_files
endif

sqlite_lib = shared_library(
  library_name,
  library_sources,
  c_args : platform_c_args,
  link_args : platform_link_args,
  dependencies : [openssl_dep],  # 添加 OpenSSL 依赖
  install : false,  # 不使用默认安装，手动复制到指定位置
  name_suffix : library_suffix.substring(1),  # 去掉前面的点
)

# 自定义安装目标
if install_dir != ''
  # 获取正确的输出文件名（考虑 Meson 自动添加的前缀）
  if host_system == 'windows'
    output_filename = library_name + library_suffix
  else
    # Unix-like 系统，Meson 会自动添加 'lib' 前缀
    output_filename = 'lib' + library_name + library_suffix
  endif
  
  custom_target('install_lib',
    input : sqlite_lib,
    output : 'install_completed.stamp',  # 使用 stamp 文件避免文件名冲突
    command : ['cp', '@INPUT@', join_paths(meson.current_source_dir(), install_dir, output_filename)],
    build_by_default : true
  )
endif

# 代码签名 (仅 macOS)
if host_system == 'darwin' and get_option('macos_codesign_identity') != ''
  codesign_identity = get_option('macos_codesign_identity')
  custom_target('codesign',
    input : sqlite_lib,
    output : 'codesigned.stamp',
    command : ['codesign', '-s', codesign_identity, '@INPUT@'],
    depends : sqlite_lib,
    build_by_default : true
  )
endif

# 显示构建信息
message('Building for: ' + host_system + '-' + host_cpu)
message('Debug mode: ' + sqlite_debug.to_string())
message('Install directory: ' + install_dir)
