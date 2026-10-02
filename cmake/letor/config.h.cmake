/* Minimal config.h for building xapian-letor against our CMake xapian-core. */
#ifndef XAPIAN_LETOR_CONFIG_H
#define XAPIAN_LETOR_CONFIG_H

#define PACKAGE "xapian-letor"
#define PACKAGE_NAME "xapian-letor"
#define PACKAGE_TARNAME "xapian-letor"
#define PACKAGE_VERSION "@PROJECT_VERSION@"
#define PACKAGE_STRING "xapian-letor @PROJECT_VERSION@"
#define PACKAGE_BUGREPORT "https://xapian.org/bugs"
#define PACKAGE_URL ""
#define VERSION "@PROJECT_VERSION@"

#define HAVE_CXX17 1
#define STDC_HEADERS 1

/* Branch prediction hints (MSVC has no __builtin_expect). */
#ifndef rare
# define rare(COND) (COND)
#endif
#ifndef usual
# define usual(COND) (COND)
#endif

#ifdef _MSC_VER
# ifndef _CRT_SECURE_NO_WARNINGS
#  define _CRT_SECURE_NO_WARNINGS
# endif
# ifndef _CRT_NONSTDC_NO_WARNINGS
#  define _CRT_NONSTDC_NO_WARNINGS
# endif
# pragma warning(disable:4003)
# pragma warning(disable:4267)
# pragma warning(disable:4244)
#endif

#endif /* XAPIAN_LETOR_CONFIG_H */
