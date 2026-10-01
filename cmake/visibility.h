/* Patch-friendly visibility header for MSVC DLL builds.
 * Upstream visibility.h only knows about GCC visibility attributes.
 * We install this as a compile-side override via -include or by
 * replacing the include path order for xapian/visibility.h.
 */
#ifndef XAPIAN_INCLUDED_VISIBILITY_H
#define XAPIAN_INCLUDED_VISIBILITY_H

#include "xapian/version.h"

#if defined(_WIN32) && defined(XAPIAN_BUILD_DLL)
#  if defined(XAPIAN_LIB_BUILD)
#    define XAPIAN_VISIBILITY_DEFAULT __declspec(dllexport)
#  else
#    define XAPIAN_VISIBILITY_DEFAULT __declspec(dllimport)
#  endif
#  define XAPIAN_VISIBILITY_INTERNAL
#elif defined(XAPIAN_ENABLE_VISIBILITY)
#  define XAPIAN_VISIBILITY_DEFAULT __attribute__((visibility("default")))
#  define XAPIAN_VISIBILITY_INTERNAL __attribute__((visibility("internal")))
#else
#  define XAPIAN_VISIBILITY_DEFAULT
#  define XAPIAN_VISIBILITY_INTERNAL
#endif

#endif
