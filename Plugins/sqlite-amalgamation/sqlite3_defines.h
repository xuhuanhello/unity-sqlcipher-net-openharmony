// Compile-time definitions used to build SQLite/SQLCipher
// This is a separate file so that IL2CPP can use the same flags on all platforms
// Feel free to change this based on your needs

// ========== SQLite 基础配置 ==========
#define SQLITE_USE_URI 1
#define SQLITE_DQS 0 
#define SQLITE_DEFAULT_MEMSTATUS 0 
#define SQLITE_DEFAULT_WAL_SYNCHRONOUS 1 
#define SQLITE_LIKE_DOESNT_MATCH_BLOBS 1
#define SQLITE_MAX_EXPR_DEPTH 0 
// 注意：SQLITE_OMIT_DECLTYPE 与 SQLITE_ENABLE_COLUMN_METADATA 冲突，已注释
// #define SQLITE_OMIT_DECLTYPE 1
#define SQLITE_OMIT_DEPRECATED 1
#define SQLITE_OMIT_PROGRESS_CALLBACK 1
#define SQLITE_OMIT_SHARED_CACHE 1
#define SQLITE_USE_ALLOCA 1

// ========== SQLite 功能扩展 ==========
#define SQLITE_ENABLE_RTREE 1
#define SQLITE_ENABLE_MATH_FUNCTIONS 1
#define HAVE_ISNAN 1
#define SQLITE_ENABLE_GEOPOLY 1
#define SQLITE_ENABLE_FTS4 1
#define SQLITE_ENABLE_FTS5 1
#define SQLITE_ENABLE_JSON1 1
#define SQLITE_ENABLE_HIDDEN_COLUMNS 1
#define SQLITE_ENABLE_COLUMN_METADATA 1

// ========== SQLCipher 加密配置 ==========
#define SQLITE_HAS_CODEC 1
#define SQLCIPHER_CRYPTO_OPENSSL 1
#define SQLITE_EXTRA_INIT sqlcipher_extra_init
#define SQLITE_EXTRA_SHUTDOWN sqlcipher_extra_shutdown

// ========== SQLCipher 运行时配置 ==========
#define SQLITE_THREADSAFE 1                    // 启用线程安全
#define SQLITE_TEMP_STORE 2                    // 临时存储模式：2=内存优先, 3=仅内存 (SQLCipher要求>=2)
#define SQLITE_DEFAULT_FOREIGN_KEYS 1          // 默认启用外键
#define SQLITE_MAX_ATTACHED 10                 // 最大附加数据库数量
#define SQLITE_SOUNDEX 1                       // 启用 Soundex 支持
