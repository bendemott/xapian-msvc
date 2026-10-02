# Feature detection for xapian-core config.h (CMake replacement for configure.ac probes).
include(CheckIncludeFile)
include(CheckIncludeFileCXX)
include(CheckSymbolExists)
include(CheckCXXSymbolExists)
include(CheckTypeSize)
include(CheckCXXSourceCompiles)
include(CheckFunctionExists)
include(CheckLibraryExists)
include(TestBigEndian)

function(xapian_check_decl result_var code_snippet)
  # Sets ${result_var} to 1 or 0 whether the declaration is available.
  # code_snippet may contain includes on separate lines before statements.
  set(_src "${code_snippet}\nint main() { return 0; }\n")
  check_cxx_source_compiles("${_src}" ${result_var}_COMPILE)
  if(${result_var}_COMPILE)
    set(${result_var} 1 PARENT_SCOPE)
  else()
    set(${result_var} 0 PARENT_SCOPE)
  endif()
endfunction()

macro(xapian_detect_features)
  set(PACKAGE "xapian-core")
  set(PACKAGE_NAME "xapian-core")
  set(PACKAGE_TARNAME "xapian-core")
  set(PACKAGE_VERSION "${PROJECT_VERSION}")
  set(PACKAGE_STRING "xapian-core ${PROJECT_VERSION}")
  set(PACKAGE_BUGREPORT "https://xapian.org/bugs")
  set(PACKAGE_URL "")
  set(VERSION "${PROJECT_VERSION}")
  set(LT_OBJDIR ".libs/")

  if(WIN32)
    set(DIR_SEPS "'\\\\'")
    set(DIR_SEPS_LIST "{ '\\\\', '/' }")
  else()
    set(DIR_SEPS "'/'")
    set(DIR_SEPS_LIST "{ '/' }")
  endif()

  test_big_endian(IS_BIG_ENDIAN)
  # Xapian uses FOLLOWS_IEEE for float serialisation; assume IEEE on modern hosts.
  set(FOLLOWS_IEEE 1)

  check_type_size("short" SIZEOF_SHORT)
  check_type_size("int" SIZEOF_INT)
  check_type_size("long" SIZEOF_LONG)
  check_type_size("long long" SIZEOF_LONG_LONG)

  # AC_TYPE_MODE_T / AC_TYPE_SSIZE_T / AC_TYPE_PID_T — define replacements when
  # the system headers omit them (MSVC). Used by safesysstat.h's mkdir(path, mode)
  # overload and various POSIX-ish call sites.
  set(CMAKE_EXTRA_INCLUDE_FILES "sys/types.h")
  check_type_size("mode_t" SIZEOF_MODE_T)
  check_type_size("ssize_t" SIZEOF_SSIZE_T)
  check_type_size("pid_t" SIZEOF_PID_T)
  set(CMAKE_EXTRA_INCLUDE_FILES)
  if(NOT HAVE_SIZEOF_MODE_T)
    set(mode_t "int")
  endif()
  if(NOT HAVE_SIZEOF_SSIZE_T)
    set(ssize_t "int")
  endif()
  if(NOT HAVE_SIZEOF_PID_T)
    # Match autoconf AC_TYPE_PID_T: __int64 on Win64, int elsewhere.
    if(WIN32 AND CMAKE_SIZEOF_VOID_P EQUAL 8)
      set(pid_t "__int64")
    else()
      set(pid_t "int")
    endif()
  endif()

  if(WIN32)
    # Vista+ (AI_ADDRCONFIG for getaddrinfo), same as configure.ac.
    set(WINVER "0x0600")
    set(_WIN32_WINNT "WINVER")
  endif()

  check_include_file("dlfcn.h" HAVE_DLFCN_H)
  check_include_file("fcntl.h" HAVE_FCNTL_H)
  check_include_file("inttypes.h" HAVE_INTTYPES_H)
  check_include_file("limits.h" HAVE_LIMITS_H)
  check_include_file("poll.h" HAVE_POLL_H)
  check_include_file("stdint.h" HAVE_STDINT_H)
  check_include_file("stdio.h" HAVE_STDIO_H)
  check_include_file("stdlib.h" HAVE_STDLIB_H)
  check_include_file("strings.h" HAVE_STRINGS_H)
  check_include_file("string.h" HAVE_STRING_H)
  check_include_file("sys/resource.h" HAVE_SYS_RESOURCE_H)
  check_include_file("sys/select.h" HAVE_SYS_SELECT_H)
  check_include_file("sys/stat.h" HAVE_SYS_STAT_H)
  check_include_file("sys/types.h" HAVE_SYS_TYPES_H)
  check_include_file("sys/uio.h" HAVE_SYS_UIO_H)
  check_include_file("sys/utsname.h" HAVE_SYS_UTSNAME_H)
  check_include_file("sysexits.h" HAVE_SYSEXITS_H)
  check_include_file("unistd.h" HAVE_UNISTD_H)
  check_include_file("zlib.h" HAVE_ZLIB_H)
  check_include_file_cxx("cxxabi.h" HAVE_CXXABI_H)

  if(WIN32)
    # UuidCreate() via rpcrt4 — not the BSD <uuid.h> API (HAVE_UUID_H).
    set(USE_WIN32_UUID_API 1)
  else()
    check_include_file("uuid/uuid.h" HAVE_UUID_UUID_H)
    check_include_file("uuid.h" HAVE_UUID_H)
  endif()

  set(CMAKE_REQUIRED_LIBRARIES "")
  # libc functions
  foreach(_fn IN ITEMS
      clock_gettime closefrom close_range fdatasync fork fsync ftime ftruncate
      getdirentries getentropy gethostname getrlimit getrusage gettimeofday
      link nanosleep nftw poll posix_fadvise pread pwrite setenv sigaction sleep
      socketpair sysconf timer_create times writev
      arc4random arc4random_buf)
    string(TOUPPER "${_fn}" _fnu)
    check_symbol_exists(${_fn} "unistd.h;fcntl.h;sys/types.h;sys/socket.h;sys/time.h;sys/resource.h;sys/uio.h;time.h;signal.h;poll.h;stdlib.h" HAVE_${_fnu})
  endforeach()

  # strerror_r / strerrordesc_np
  check_symbol_exists(strerror_r "string.h" HAVE_STRERROR_R)
  check_symbol_exists(strerrordesc_np "string.h" HAVE_STRERRORDESC_NP)
  check_cxx_source_compiles("
    #include <string.h>
    int main() {
      char buf[64];
      char* p = strerror_r(0, buf, sizeof buf);
      (void)p;
      return 0;
    }" STRERROR_R_CHAR_P)

  check_cxx_source_compiles("
    #include <charconv>
    int main() {
      double d;
      auto r = std::from_chars(static_cast<const char*>(nullptr),
                               static_cast<const char*>(nullptr), d);
      (void)r; (void)d;
      return 0;
    }" HAVE_STD_FROM_CHARS_DOUBLE)

  # Builtin / intrinsic declarations (1/0). Snippets run in global scope + empty main.
  xapian_check_decl(HAVE_DECL___BUILTIN_EXPECT "static long x = __builtin_expect(0,0);")
  xapian_check_decl(HAVE_DECL___BUILTIN_CLZ "static int x = __builtin_clz(1u);")
  xapian_check_decl(HAVE_DECL___BUILTIN_CLZL "static int x = __builtin_clzl(1ul);")
  xapian_check_decl(HAVE_DECL___BUILTIN_CLZLL "static int x = __builtin_clzll(1ull);")
  xapian_check_decl(HAVE_DECL___BUILTIN_CTZ "static int x = __builtin_ctz(1u);")
  xapian_check_decl(HAVE_DECL___BUILTIN_CTZL "static int x = __builtin_ctzl(1ul);")
  xapian_check_decl(HAVE_DECL___BUILTIN_CTZLL "static int x = __builtin_ctzll(1ull);")
  xapian_check_decl(HAVE_DECL___BUILTIN_FFS "static int x = __builtin_ffs(1);")
  xapian_check_decl(HAVE_DECL___BUILTIN_POPCOUNT "static int x = __builtin_popcount(1u);")
  xapian_check_decl(HAVE_DECL___BUILTIN_POPCOUNTL "static int x = __builtin_popcountl(1ul);")
  xapian_check_decl(HAVE_DECL___BUILTIN_POPCOUNTLL "static int x = __builtin_popcountll(1ull);")
  xapian_check_decl(HAVE_DECL___BUILTIN_BSWAP16 "static auto x = __builtin_bswap16(1);")
  xapian_check_decl(HAVE_DECL___BUILTIN_BSWAP32 "static auto x = __builtin_bswap32(1);")
  xapian_check_decl(HAVE_DECL___BUILTIN_BSWAP64 "static auto x = __builtin_bswap64(1);")
  xapian_check_decl(HAVE_DECL___BUILTIN_ADD_OVERFLOW "static int x; static bool y = __builtin_add_overflow(1,1,&x);")
  xapian_check_decl(HAVE_DECL___BUILTIN_SUB_OVERFLOW "static int x; static bool y = __builtin_sub_overflow(1,1,&x);")
  xapian_check_decl(HAVE_DECL___BUILTIN_MUL_OVERFLOW "static int x; static bool y = __builtin_mul_overflow(1,1,&x);")
  xapian_check_decl(HAVE_DECL_EXP10 "extern \"C\" double exp10(double); static double x = exp10(1.0);")
  xapian_check_decl(HAVE_DECL___EXP10 "extern \"C\" double __exp10(double); static double x = __exp10(1.0);")
  xapian_check_decl(HAVE_DECL_SIGSETJMP "#include <setjmp.h>\nstatic void f(){sigjmp_buf b; (void)sigsetjmp(b,0);}")
  xapian_check_decl(HAVE_DECL_SIGLONGJMP "#include <setjmp.h>\nstatic void f(){sigjmp_buf b; if(sigsetjmp(b,0)){} else siglongjmp(b,1);}")
  xapian_check_decl(HAVE_DECL_STRERROR_R "#include <string.h>\nstatic void f(){char buf[8]; (void)strerror_r(0,buf,8);}")

  # MSVC intrinsics
  xapian_check_decl(HAVE_DECL___POPCNT "#include <intrin.h>\nstatic auto x = __popcnt(1u);")
  xapian_check_decl(HAVE_DECL___POPCNT64 "#include <intrin.h>\nstatic auto x = __popcnt64(1ull);")
  xapian_check_decl(HAVE_DECL__BYTESWAP_USHORT "#include <stdlib.h>\nstatic auto x = _byteswap_ushort(1);")
  xapian_check_decl(HAVE_DECL__BYTESWAP_ULONG "#include <stdlib.h>\nstatic auto x = _byteswap_ulong(1);")
  xapian_check_decl(HAVE_DECL__BYTESWAP_UINT64 "#include <stdlib.h>\nstatic auto x = _byteswap_uint64(1);")
  xapian_check_decl(HAVE_DECL__PUTENV_S "#include <stdlib.h>\nstatic int x = _putenv_s(\"A\",\"B\");")
  xapian_check_decl(HAVE_DECL__ADDCARRY_U32 "#include <intrin.h>\nstatic void f(){unsigned r; (void)_addcarry_u32(0,1u,1u,&r);}")
  xapian_check_decl(HAVE_DECL__ADDCARRY_U64 "#include <intrin.h>\nstatic void f(){unsigned long long r; (void)_addcarry_u64(0,1ull,1ull,&r);}")
  xapian_check_decl(HAVE_DECL__SUBBORROW_U32 "#include <intrin.h>\nstatic void f(){unsigned r; (void)_subborrow_u32(0,1u,1u,&r);}")
  xapian_check_decl(HAVE_DECL__SUBBORROW_U64 "#include <intrin.h>\nstatic void f(){unsigned long long r; (void)_subborrow_u64(0,1ull,1ull,&r);}")

  set(HAVE__PUTENV_S ${HAVE_DECL__PUTENV_S})

  set(STDC_HEADERS 1)
  set(USE_RTTI 1)
  set(SOCKLEN_T socklen_t)

  if(NOT WIN32 AND NOT APPLE)
    # fortify probe — enable on glibc-like when using GCC/Clang
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
      set(FORTIFY_SOURCE_OK 1)
    endif()
  endif()

  if(MSVC)
    set(HAVE_DECL___BUILTIN_EXPECT 0)
  endif()
endmacro()
