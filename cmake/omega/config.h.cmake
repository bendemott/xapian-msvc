/* Minimal config.h for xapian-omega under CMake (MSVC-friendly). */
#cmakedefine HAVE_CXX17 1
#cmakedefine HAVE_FCNTL_H 1
#cmakedefine HAVE_INTTYPES_H 1
#cmakedefine HAVE_STDINT_H 1
#cmakedefine HAVE_STDIO_H 1
#cmakedefine HAVE_STDLIB_H 1
#cmakedefine HAVE_STRING_H 1
#cmakedefine HAVE_SYS_STAT_H 1
#cmakedefine HAVE_SYS_TYPES_H 1
#cmakedefine HAVE_UNISTD_H 1
#cmakedefine HAVE_ZLIB_H 1

#cmakedefine HAVE_FORK 1
#cmakedefine HAVE_FTIME 1
#cmakedefine HAVE_GETTIMEOFDAY 1
#cmakedefine HAVE_LINK 1
#cmakedefine HAVE_LSTAT 1
#cmakedefine HAVE_MKDTEMP 1
#cmakedefine HAVE_MKSTEMP 1
#cmakedefine HAVE_NICE 1
#cmakedefine HAVE_SETENV 1
#cmakedefine HAVE_SLEEP 1
#cmakedefine HAVE_STRPTIME 1
#cmakedefine HAVE_SYSCONF 1
#cmakedefine HAVE_TIMEGM 1
#cmakedefine HAVE_GMTIME_R 1
#cmakedefine HAVE_LOCALTIME_R 1
#cmakedefine HAVE_CLOSEFROM 1
#cmakedefine HAVE_SOCKETPAIR 1
#cmakedefine HAVE_SYS_WAIT_H 1
#cmakedefine HAVE_SYS_SELECT_H 1
#cmakedefine HAVE_SYS_RESOURCE_H 1
#cmakedefine HAVE_DIRENT_H 1

#cmakedefine HAVE_ICONV 1
#cmakedefine HAVE_LIBMAGIC 1
#cmakedefine HAVE_PCRE2 1
#cmakedefine HAVE__PUTENV_S 1
#cmakedefine01 HAVE_DECL__PUTENV_S

#cmakedefine STDC_HEADERS 1

#define PACKAGE "@PACKAGE@"
#define PACKAGE_NAME "@PACKAGE_NAME@"
#define PACKAGE_STRING "@PACKAGE_STRING@"
#define PACKAGE_TARNAME "@PACKAGE_TARNAME@"
#define PACKAGE_VERSION "@PACKAGE_VERSION@"
#define PACKAGE_BUGREPORT "@PACKAGE_BUGREPORT@"
#define PACKAGE_URL "@PACKAGE_URL@"
#define VERSION "@VERSION@"

#cmakedefine mode_t @mode_t@
#cmakedefine ssize_t @ssize_t@
#cmakedefine pid_t @pid_t@

/* type to use for 5th parameter to getsockopt */
#define SOCKLEN_T @SOCKLEN_T@

#cmakedefine WINVER @WINVER@
#cmakedefine _WIN32_WINNT @_WIN32_WINNT@

#ifdef _MSC_VER
# pragma warning(disable:4003)
# pragma warning(disable:4267)
# pragma warning(disable:4244)
# pragma warning(disable:4996)
# ifndef _CRT_NONSTDC_NO_WARNINGS
#  define _CRT_NONSTDC_NO_WARNINGS
# endif
# ifndef _CRT_SECURE_NO_WARNINGS
#  define _CRT_SECURE_NO_WARNINGS
# endif
# ifndef NOMINMAX
#  define NOMINMAX
# endif
#endif

#if !defined __WIN32__ && defined _WIN32
# define __WIN32__
#endif
#if !defined __WIN64__ && defined _WIN64
# define __WIN64__
#endif

#define ZLIB_CONST

#if HAVE_DECL___BUILTIN_EXPECT
# define rare(COND) __builtin_expect(!!(COND), 0)
# define usual(COND) __builtin_expect(!!(COND), 1)
#else
# define rare(COND) (COND)
# define usual(COND) (COND)
#endif

#ifdef __clang__
# define UNSIGNED_OVERFLOW_OK(X) \
    ([&]() __attribute__((no_sanitize("unsigned-integer-overflow"))) { return (X); }())
#else
# define UNSIGNED_OVERFLOW_OK(X) (X)
#endif
