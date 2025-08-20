project('unity-sqlite-net', 'c',
  version : '1.0.0',
  default_options : [
    'warning_level=1',
    'c_std=c99'
  ]
)

# 构建选项
sqlite_debug = get_option('debug')

# 源文件路径
sqlite_src = '../Plugins/sqlite-amalgamation/sqlite3.c'

# 基础编译参数
base_c_args = []
base_link_args = []

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
  library_name = 'libgilzoide-sqlite-net'
  library_suffix = '.so'
  if host_cpu == 'x86_64'
    install_dir = '../Plugins/lib/linux/x86_64'
  endif

# macOS 配置
elif host_system == 'darwin'
  # Universal binary (arm64 + x86_64)
  platform_c_args += ['-arch', 'arm64', '-arch', 'x86_64']
  platform_link_args += ['-shared', '-arch', 'arm64', '-arch', 'x86_64']
  library_name = 'libgilzoide-sqlite-net'
  library_suffix = '.dylib'
  install_dir = '../Plugins/lib/macos'

# Android 配置 (通过交叉编译文件处理)
elif host_system.contains('android') or get_option('android_build')
  platform_c_args += ['-fPIC']
  platform_link_args += ['-shared', '-lm', '-Wl,-z,max-page-size=16384']
  library_name = 'libgilzoide-sqlite-net'
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
sqlite_lib = shared_library(
  library_name,
  sqlite_src,
  c_args : platform_c_args,
  link_args : platform_link_args,
  install : false,  # 不使用默认安装，手动复制到指定位置
  name_suffix : library_suffix.substring(1),  # 去掉前面的点
)

# 自定义安装目标
if install_dir != ''
  custom_target('install_lib',
    input : sqlite_lib,
    output : library_name + library_suffix,
    command : ['cp', '@INPUT@', join_paths(meson.current_source_dir(), install_dir, '@OUTPUT@')],
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
