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

/* No _DEBUG guard here: a multi-config or vcpkg build installs one copy of
 * this header for both Debug and Release libraries. MSVC already rejects a
 * debug/release CRT mix at link time (_ITERATOR_DEBUG_LEVEL / RuntimeLibrary
 * mismatch), so a header check adds nothing and breaks those builds. */

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

#endif /* XAPIAN_INCLUDED_VERSION_H */

/*
 * DLL note: upstream include/xapian/visibility.h defines XAPIAN_VISIBILITY_*
 * unconditionally (GCC attributes or empty). For MSVC DLLs, patch that header
 * (or inject before it) so that on _WIN32 + XAPIAN_BUILD_DLL it uses
 * __declspec(dllexport) while building the lib and dllimport for consumers.
 */
