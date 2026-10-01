/** @file
 * @brief CMake-generated xapian/version.h (skeleton).
 *
 * Upstream generates this by preprocessing version_h.cc. Emitting it from
 * CMake is simpler for an MSVC-native port; keep fields aligned with upstream.
 */
#ifndef XAPIAN_INCLUDED_VERSION_H
#define XAPIAN_INCLUDED_VERSION_H

#if !defined XAPIAN_IN_XAPIAN_H && !defined XAPIAN_LIB_BUILD
# error Never use <xapian/version.h> directly; include <xapian.h> instead.
#endif

#ifdef _MSC_VER
/* Applications must use the same _DEBUG setting as the library build. */
# ifdef XAPIAN_CMAKE_LIBRARY_DEBUG
#  ifndef _DEBUG
#   error This library was compiled with _DEBUG defined; settings must match.
#  endif
# else
#  ifdef _DEBUG
#   error You defined _DEBUG but the library was not built that way.
#  endif
# endif
#endif

#define XAPIAN_VERSION @STRING_VERSION@
#define XAPIAN_MAJOR_VERSION @MAJOR_VERSION@
#define XAPIAN_MINOR_VERSION @MINOR_VERSION@
#define XAPIAN_REVISION @REVISION@

#define XAPIAN_DOCID_BASE_TYPE @XAPIAN_DOCID_BASE_TYPE@
#define XAPIAN_TERMCOUNT_BASE_TYPE @XAPIAN_TERMCOUNT_BASE_TYPE@
#define XAPIAN_TERMPOS_BASE_TYPE @XAPIAN_TERMPOS_BASE_TYPE@
#define XAPIAN_TOTALLENGTH_TYPE @XAPIAN_REVISION_TYPE@
#define XAPIAN_REVISION_TYPE @XAPIAN_REVISION_TYPE@

#cmakedefine XAPIAN_HAS_GLASS_BACKEND 1
#cmakedefine XAPIAN_HAS_HONEY_BACKEND 1
#cmakedefine XAPIAN_HAS_INMEMORY_BACKEND 1
#cmakedefine XAPIAN_HAS_REMOTE_BACKEND 1

/* DLL helpers for a CMake MSVC shared build (not in upstream visibility.h). */
#if defined(_WIN32) && defined(XAPIAN_BUILD_DLL)
# if defined(XAPIAN_LIB_BUILD)
#  define XAPIAN_VISIBILITY_DEFAULT __declspec(dllexport)
# else
#  define XAPIAN_VISIBILITY_DEFAULT __declspec(dllimport)
# endif
# define XAPIAN_VISIBILITY_INTERNAL
#endif

#endif /* XAPIAN_INCLUDED_VERSION_H */
