project('unity-sqlcipher-net', 'c',
  version : '1.2.0',
  meson_version : '>=1.2.0',
  default_options : [
    'warning_level=1',
    'c_std=gnu99',  # 使用 GNU C99 支持汇编语法
    'default_library=static'  # 强制 OpenSSL 为静态库
  ]
)

# 导入必要的模块
fs = import('fs')
cc = meson.get_compiler('c')

# 构建选项
sqlite_debug = get_option('debug')

# 获取iOS SDK信息（如果是Darwin平台）
ios_sdk = ''
if host_machine.system() == 'darwin'
  ios_sdk = get_option('ios_sdk')
endif

# OpenSSL 依赖 (强制使用指定的 3.0.8 版本，不检查系统版本)
# 为 macOS Universal Binary、iOS 和 Android x86 构建禁用汇编优化以避免架构冲突
openssl_options = {}
if host_machine.system() == 'darwin'
  # 在 macOS Universal Binary 和 iOS 构建中禁用汇编优化
  openssl_options = {'asm': 'disabled'}
  
  # iOS平台OpenSSL使用静态库
  if ios_sdk == 'iphoneos' or ios_sdk == 'iphonesimulator'
    openssl_options += {
      'default_library': 'static'
    }
  endif
elif host_machine.system() == 'android' and host_machine.cpu_family() == 'x86'
  # 在 Android x86 (32位) 构建中禁用汇编优化以避免原子操作问题
  openssl_options = {'asm': 'disabled'}
endif

openssl_subproject = subproject('openssl', default_options : openssl_options)
openssl_dep = openssl_subproject.get_variable('libcrypto_dep')

# 源文件路径 (现在应该是 SQLCipher 源码)
# 智能路径检测以支持Docker和本地构建
current_dir = meson.current_source_dir()

# 先定义project_root，确保所有分支都有这个变量
project_root = current_dir / '..'

# 检测是否在Docker环境中 (工作目录直接是MesonBuild~内容)
if fs.exists(current_dir / 'cross-files')
  # Docker环境：当前目录包含MesonBuild~内容
  message('Docker environment detected. Current dir: ' + current_dir)
  message('Listing /workspace contents...')

  # 使用run_command来列出目录内容
  ls_result = run_command('ls', '-la', '/workspace', check: false)
  if ls_result.returncode() == 0
    message('Contents of /workspace:')
    foreach line : ls_result.stdout().strip().split('\n')
      message('  ' + line)
    endforeach
  else
    message('Failed to list /workspace contents')
  endif

  # 也检查上级目录
  ls_parent_result = run_command('ls', '-la', '/workspace/..', check: false)
  if ls_parent_result.returncode() == 0
    message('Contents of /workspace/..:')
    foreach line : ls_parent_result.stdout().strip().split('\n')
      message('  ' + line)
    endforeach
  else
    message('Failed to list /workspace/.. contents')
  endif

  # 尝试多个可能的SQLite路径
  possible_paths = [
    '/workspace/Plugins/sqlite-amalgamation/sqlite3.c',           # 如果整个项目都在/workspace
    '/workspace/../Plugins/sqlite-amalgamation/sqlite3.c',       # 项目在workspace的上级
    '/workspace/../../Plugins/sqlite-amalgamation/sqlite3.c',    # 项目在workspace的上上级
    current_dir / '../Plugins/sqlite-amalgamation/sqlite3.c',    # 标准相对路径
    current_dir / '../../Plugins/sqlite-amalgamation/sqlite3.c', # 向上两级目录
    '/Plugins/sqlite-amalgamation/sqlite3.c'                     # 绝对路径（不太可能）
  ]

  sqlite_src = ''
  foreach path : possible_paths
    if fs.exists(path)
      sqlite_src = path
      message('Found SQLite source in Docker environment: ' + path)
      break
    endif
  endforeach

  # 如果都没找到，使用默认路径（Docker挂载修复后应该能找到）
  if sqlite_src == ''
    message('SQLite source not found in Docker environment, trying paths:')
    foreach path : possible_paths
      message('  Checked: ' + path + ' - ' + (fs.exists(path) ? 'EXISTS' : 'NOT FOUND'))
    endforeach

    # 使用默认路径，Docker挂载修复后应该能工作
    sqlite_src = project_root / 'Plugins/sqlite-amalgamation/sqlite3.c'
    message('Using default path: ' + sqlite_src)
  endif
else
  # 本地环境：正常的项目结构
  sqlite_src = project_root / 'Plugins/sqlite-amalgamation/sqlite3.c'
endif

# SQLCipher 编译定义 - 现在通过头文件统一配置
sqlcipher_c_args = [
  # 类型支持
  '-D_GNU_SOURCE',                     # 启用 GNU 扩展，包含完整的类型定义
  '-include', 'stdint.h',              # 强制包含 stdint.h 头文件
  
  # 强制包含 SQLite/SQLCipher 配置文件
  '-include', project_root / 'Plugins/sqlite-amalgamation/sqlite3_defines.h',
]

# 符号隐藏配置 (防止 OpenSSL 符号冲突)
symbol_hiding_args = []
symbol_export_files = []

if host_machine.system() == 'windows'
  # Windows 使用 .def 文件控制符号导出
  symbol_hiding_args = []
elif host_machine.system() == 'darwin'
  # macOS/iOS 使用 -exported_symbols_list 来限制导出符号
  if ios_sdk == 'iphoneos' or ios_sdk == 'iphonesimulator'
    # iOS 使用详细的符号列表
    symbol_hiding_args = ['-Wl,-exported_symbols_list,' + meson.current_source_dir() + '/exports/exports.ios.symbols']
  else
    # macOS 使用通配符符号列表
    symbol_hiding_args = ['-Wl,-exported_symbols_list,' + meson.current_source_dir() + '/exports/exports.macos.symbols']
  endif
elif host_machine.system() == 'harmony'
  # HarmonyOS 使用版本脚本隐藏符号
  symbol_hiding_args += ['-Wl,--version-script=' + meson.current_source_dir() + '/exports/exports.harmony.map']
elif host_machine.system() == 'android' or get_option('android_build')
  # Android 使用专门的版本脚本，精确控制符号导出
  symbol_hiding_args += ['-Wl,--version-script=' + meson.current_source_dir() + '/exports/exports.android.map']
else
  # Unix-like 系统使用版本脚本隐藏符号
  symbol_hiding_args += ['-Wl,--version-script=' + meson.current_source_dir() + '/exports/exports.linux.map']
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
  # iOS SDK 信息已在前面获取
  if ios_sdk == 'iphoneos'
    # iOS 设备配置 - 使用静态库，符号控制在Unity链接时处理
    platform_c_args += ['-fPIC']
    # iOS静态库不需要-shared链接参数
    library_suffix = '.a'
    library_name = 'gilzoide-sqlite-net'  # Unity DllImport使用的库名
    install_dir = '../Plugins/lib/ios'
  elif ios_sdk == 'iphonesimulator'
    # iOS 模拟器配置 - 使用静态库，符号控制在Unity链接时处理
    platform_c_args += ['-fPIC']
    # iOS静态库不需要-shared链接参数
    library_suffix = '.a'
    library_name = 'gilzoide-sqlite-net'  # Unity DllImport使用的库名
    install_dir = '../Plugins/lib/ios-simulator'
  else
    # macOS Universal binary (arm64 + x86_64)
    platform_c_args += ['-arch', 'arm64', '-arch', 'x86_64']
    platform_link_args += ['-shared', '-arch', 'arm64', '-arch', 'x86_64']
    # macOS 使用不带 lib 前缀的名称，以匹配 Unity DllImport
    library_suffix = '.dylib'
    install_dir = '../Plugins/lib/macos'
  endif

# Android 配置 (通过交叉编译文件处理)
elif host_system.contains('android') or get_option('android_build')
  platform_c_args += ['-fPIC']
  platform_link_args += ['-shared', '-lm', '-llog']  # Android 库依赖，16KB对齐通过交叉编译文件设置
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

# HarmonyOS 配置 (通过交叉编译文件处理)
elif host_system.contains('harmony') or get_option('harmony_build')
  platform_c_args += [
    '-fPIC',
    '-D__MUSL__',
    '-DOHOS_PLATFORM'
  ]
  platform_link_args += [
    '-shared', 
    '-lm'
  ]
  # 保持默认名称，Meson 会自动添加 'lib' 前缀
  library_suffix = '.so'
  
  harmony_abi = get_option('harmony_abi')
  harmony_stl = get_option('harmony_stl')
  
  if harmony_abi == 'arm64-v8a'
    install_dir = '../Plugins/lib/OpenHarmony/arm64'
    # 确保使用正确的目标架构
    platform_c_args += ['--target=aarch64-linux-ohos']
    platform_link_args += ['--target=aarch64-linux-ohos']
  endif
  
  # 根据 STL 选择添加相应的链接参数
  if harmony_stl == 'c++_shared'
    platform_link_args += ['-lc++_shared']
  elif harmony_stl == 'c++_static'
    platform_link_args += ['-static-libstdc++']
  endif
endif

# 确保输出目录存在
if install_dir != ''
  run_command('mkdir', '-p', install_dir, check: false)
endif

# 构建库 (根据平台选择静态或动态)
library_sources = [sqlite_src]

# Windows 平台添加 .def 文件通过链接参数 (MinGW 需要这样处理)
windows_def_args = []
if host_machine.system() == 'windows'
  windows_def_args = [meson.current_source_dir() + '/exports/exports.windows.def']
endif

# 准备库构建的额外参数
extra_args = {
  'c_args' : platform_c_args,
  'link_args' : platform_link_args + windows_def_args,
  'dependencies' : [openssl_dep],  # 添加 OpenSSL 依赖
  'install' : false,  # 不使用默认安装，手动复制到指定位置
  'name_suffix' : library_suffix.substring(1),  # 去掉前面的点
}

# iOS平台构建静态库，其他平台构建动态库
if host_system == 'darwin' and (ios_sdk == 'iphoneos' or ios_sdk == 'iphonesimulator')
  # iOS 使用静态库
  sqlite_lib = static_library(
    library_name,
    library_sources,
    kwargs : extra_args
  )
  
  # 为iOS创建合并了OpenSSL的最终静态库
  openssl_crypto_lib = openssl_subproject.get_variable('libcrypto_lib')
  openssl_ssl_lib = openssl_subproject.get_variable('libssl_lib')
  
  # 创建自定义目标来合并静态库
  merge_script = join_paths(meson.current_source_dir(), 'scripts', 'merge-static-libs.sh')
  merged_lib_target = custom_target('merged_static_lib',
    input : [sqlite_lib, openssl_crypto_lib, openssl_ssl_lib],
    output : 'lib' + library_name + '_merged.a',
    command : [merge_script, '@OUTPUT@', '@INPUT0@', '@INPUT1@', '@INPUT2@'],
    depends : [sqlite_lib, openssl_crypto_lib, openssl_ssl_lib],
    build_by_default : true
  )
  
  # 用合并后的库替换原始库进行后续安装
  final_lib = merged_lib_target
else
  # 其他平台使用动态库
  sqlite_lib = shared_library(
    library_name,
    library_sources,
    kwargs : extra_args
  )
  final_lib = sqlite_lib
endif

# 自定义安装目标
if install_dir != ''
  # 获取正确的输出文件名（考虑 Meson 自动添加的前缀）
  if host_system == 'windows'
    output_filename = library_name + library_suffix
  elif host_system == 'darwin' and (ios_sdk == 'iphoneos' or ios_sdk == 'iphonesimulator')
    # iOS 静态库，使用合并后的库文件名
    output_filename = 'lib' + library_name + library_suffix
  elif host_system == 'darwin'
    # macOS 动态库，使用不带 lib 前缀的名称以匹配 Unity DllImport
    output_filename = library_name + library_suffix
  else
    # Unix-like 系统，Meson 会自动添加 'lib' 前缀
    output_filename = 'lib' + library_name + library_suffix
  endif
  
  # 根据平台选择正确的库文件进行安装
  if host_system == 'darwin' and ios_sdk == ''
    # macOS 需要重命名去掉 lib 前缀
    custom_target('install_lib',
      input : final_lib,
      output : 'install_completed.stamp',  # 使用 stamp 文件避免文件名冲突
      command : ['sh', '-c', 'cp @INPUT@ ' + join_paths(meson.current_source_dir(), install_dir, output_filename) + ' && install_name_tool -id "' + output_filename + '" ' + join_paths(meson.current_source_dir(), install_dir, output_filename)],
      build_by_default : true
    )
  else
    custom_target('install_lib',
      input : final_lib,
      output : 'install_completed.stamp',  # 使用 stamp 文件避免文件名冲突
      command : ['cp', '@INPUT@', join_paths(meson.current_source_dir(), install_dir, output_filename)],
      build_by_default : true
    )
  endif
endif

# iOS 静态库不需要Framework打包和代码签名

# macOS 代码签名
if host_system == 'darwin' and ios_sdk == '' and get_option('macos_codesign_identity') != ''
  codesign_identity = get_option('macos_codesign_identity')
  custom_target('codesign',
    input : final_lib,
    output : 'codesigned.stamp',
    command : ['codesign', '-s', codesign_identity, '@INPUT@'],
    depends : final_lib,
    build_by_default : true
  )
endif

# 显示构建信息
message('Building for: ' + host_system + '-' + host_cpu)
message('Debug mode: ' + sqlite_debug.to_string())
message('Install directory: ' + install_dir)
