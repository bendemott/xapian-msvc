# CMake build for xapian-omega (core tools; optional format handlers off).
# Expects Xapian::xapian, XAPIAN_ZLIB_TARGET, and PROJECT_VERSION from the parent.

set(OMEGA_ROOT "${CMAKE_SOURCE_DIR}/third_party/xapian-omega" CACHE PATH
    "Path to xapian-omega sources")

if(NOT EXISTS "${OMEGA_ROOT}/omindex.cc")
  include(FetchContent)
  message(STATUS "xapian-omega not at ${OMEGA_ROOT}; downloading ${PROJECT_VERSION}")
  FetchContent_Declare(
    xapian_omega_src
    URL "https://oligarchy.co.uk/xapian/${PROJECT_VERSION}/xapian-omega-${PROJECT_VERSION}.tar.xz"
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  )
  FetchContent_MakeAvailable(xapian_omega_src)
  set(OMEGA_ROOT "${xapian_omega_src_SOURCE_DIR}" CACHE PATH "Path to xapian-omega sources" FORCE)
endif()

if(NOT EXISTS "${OMEGA_ROOT}/omindex.cc")
  message(FATAL_ERROR "xapian-omega sources not found. Run: python scripts/import-xapian.py omega")
endif()

# --- config.h ---
set(PACKAGE "xapian-omega")
set(PACKAGE_NAME "xapian-omega")
set(PACKAGE_TARNAME "xapian-omega")
set(PACKAGE_VERSION "${PROJECT_VERSION}")
set(PACKAGE_STRING "xapian-omega ${PROJECT_VERSION}")
set(PACKAGE_BUGREPORT "https://xapian.org/bugs")
set(PACKAGE_URL "")
set(VERSION "${PROJECT_VERSION}")
set(HAVE_CXX17 1)
set(HAVE_FCNTL_H 1)
set(HAVE_INTTYPES_H 1)
set(HAVE_STDINT_H 1)
set(HAVE_STDIO_H 1)
set(HAVE_STDLIB_H 1)
set(HAVE_STRING_H 1)
set(HAVE_SYS_STAT_H 1)
set(HAVE_SYS_TYPES_H 1)
set(HAVE_ZLIB_H 1)
set(STDC_HEADERS 1)
set(HAVE_PCRE2 1)

if(WIN32)
  set(HAVE_FTIME 1)
  set(HAVE__PUTENV_S 1)
  set(HAVE_DECL__PUTENV_S 1)
  set(WINVER "0x0600")
  set(_WIN32_WINNT "WINVER")
  set(SOCKLEN_T "int")
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(pid_t "__int64")
  else()
    set(pid_t "int")
  endif()
  set(mode_t "int")
  set(ssize_t "int")
else()
  set(SOCKLEN_T "socklen_t")
  set(HAVE_UNISTD_H 1)
  set(HAVE_FORK 1)
  set(HAVE_GETTIMEOFDAY 1)
  set(HAVE_LINK 1)
  set(HAVE_LSTAT 1)
  set(HAVE_MKDTEMP 1)
  set(HAVE_MKSTEMP 1)
  set(HAVE_SETENV 1)
  set(HAVE_SLEEP 1)
  set(HAVE_STRPTIME 1)
  set(HAVE_SYSCONF 1)
  set(HAVE_SOCKETPAIR 1)
  # sigaction avoids glibc-only sighandler_t. waitpid selects the Unix branch
  # in worker.cc (the #else is the "needs porting" error).
  set(HAVE_SIGACTION 1)
  set(HAVE_WAITPID 1)
  set(HAVE_SYS_WAIT_H 1)
  set(HAVE_SYS_SELECT_H 1)
  set(HAVE_DIRENT_H 1)
endif()

# Linux glibc has closefrom(); macOS does not. The bundled common/closefrom.cc
# supplies it only when this is unset.
if(NOT WIN32)
  include(CheckFunctionExists)
  check_function_exists(closefrom HAVE_CLOSEFROM)
endif()

set(OMEGA_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}")
configure_file(
  "${CMAKE_SOURCE_DIR}/cmake/omega/config.h.cmake"
  "${OMEGA_BINARY_DIR}/config.h"
  @ONLY)

# --- PCRE2 (required by omega CGI / libtransform) ---
find_package(PCRE2 CONFIG QUIET COMPONENTS 8BIT)
if(NOT PCRE2_FOUND AND NOT TARGET PCRE2::8BIT)
  find_package(PkgConfig QUIET)
  if(PkgConfig_FOUND)
    pkg_check_modules(PCRE2 IMPORTED_TARGET libpcre2-8)
  endif()
endif()
if(NOT TARGET PCRE2::8BIT AND NOT TARGET PkgConfig::PCRE2)
  message(STATUS "PCRE2 not found; fetching via FetchContent")
  include(FetchContent)
  set(PCRE2_BUILD_TESTS OFF CACHE BOOL "" FORCE)
  set(PCRE2_BUILD_PCRE2GREP OFF CACHE BOOL "" FORCE)
  set(BUILD_SHARED_LIBS_SAVED "${BUILD_SHARED_LIBS}")
  set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
  FetchContent_Declare(
    pcre2
    URL https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.bz2
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  )
  # Quiet pcre2's cmake_minimum_required(<3.10) deprecation on CMake 4+.
  set(_pcre2_cmake_txt "${CMAKE_BINARY_DIR}/_deps/pcre2-src/CMakeLists.txt")
  if(EXISTS "${_pcre2_cmake_txt}")
    file(READ "${_pcre2_cmake_txt}" _pcre2_cmake)
    string(REGEX REPLACE
      "cmake_minimum_required\\(VERSION[^\n]*\\)"
      "cmake_minimum_required(VERSION 3.16)"
      _pcre2_cmake "${_pcre2_cmake}")
    file(WRITE "${_pcre2_cmake_txt}" "${_pcre2_cmake}")
  endif()
  FetchContent_MakeAvailable(pcre2)
  # First fetch: patch after extract for the next reconfigure (and current tree).
  if(DEFINED pcre2_SOURCE_DIR AND EXISTS "${pcre2_SOURCE_DIR}/CMakeLists.txt")
    file(READ "${pcre2_SOURCE_DIR}/CMakeLists.txt" _pcre2_cmake)
    string(REGEX REPLACE
      "cmake_minimum_required\\(VERSION[^\n]*\\)"
      "cmake_minimum_required(VERSION 3.16)"
      _pcre2_cmake "${_pcre2_cmake}")
    file(WRITE "${pcre2_SOURCE_DIR}/CMakeLists.txt" "${_pcre2_cmake}")
    set_property(DIRECTORY "${pcre2_SOURCE_DIR}" PROPERTY EXCLUDE_FROM_ALL TRUE)
  endif()
  set(BUILD_SHARED_LIBS "${BUILD_SHARED_LIBS_SAVED}" CACHE BOOL "" FORCE)
endif()

if(TARGET PCRE2::8BIT)
  set(OMEGA_PCRE_TARGET PCRE2::8BIT)
elseif(TARGET pcre2-8-static)
  set(OMEGA_PCRE_TARGET pcre2-8-static)
elseif(TARGET pcre2-8)
  set(OMEGA_PCRE_TARGET pcre2-8)
elseif(TARGET PkgConfig::PCRE2)
  set(OMEGA_PCRE_TARGET PkgConfig::PCRE2)
else()
  message(FATAL_ERROR "PCRE2 required for xapian-omega but no target was found")
endif()

# --- libmagic (optional on Windows: use stub) ---
set(OMEGA_USE_MAGIC_STUB OFF)
find_path(MAGIC_INCLUDE_DIR magic.h)
find_library(MAGIC_LIBRARY magic)
if(MAGIC_INCLUDE_DIR AND MAGIC_LIBRARY)
  set(HAVE_LIBMAGIC 1)
  set(OMEGA_MAGIC_LIBS ${MAGIC_LIBRARY})
  set(OMEGA_MAGIC_INCLUDES ${MAGIC_INCLUDE_DIR})
else()
  if(WIN32 OR NOT MAGIC_INCLUDE_DIR)
    message(STATUS "libmagic not found; using cmake/omega magic stub (extension MIME only)")
    set(OMEGA_USE_MAGIC_STUB ON)
    set(HAVE_LIBMAGIC 1)
    file(MAKE_DIRECTORY "${OMEGA_BINARY_DIR}/magic_include")
    configure_file(
      "${CMAKE_SOURCE_DIR}/cmake/omega/magic_stub.h"
      "${OMEGA_BINARY_DIR}/magic_include/magic.h"
      COPYONLY)
    set(OMEGA_MAGIC_INCLUDES "${OMEGA_BINARY_DIR}/magic_include")
    set(OMEGA_MAGIC_STUB_SRC "${CMAKE_SOURCE_DIR}/cmake/omega/magic_stub.c")
  else()
    message(FATAL_ERROR "libmagic required for omindex (install libmagic-dev)")
  endif()
endif()

# Re-configure config.h now that HAVE_LIBMAGIC is known
configure_file(
  "${CMAKE_SOURCE_DIR}/cmake/omega/config.h.cmake"
  "${OMEGA_BINARY_DIR}/config.h"
  @ONLY)

# MSVC's string_view::iterator is not a raw pointer, so constructions like
# string_view(it, it2 - it) fail. Patch xmlparser into the build tree.
if(MSVC)
  file(READ "${OMEGA_ROOT}/xmlparser.cc" _OMEGA_XMLPARSER_CC)
  string(REPLACE
    "string_view decl(p + 6, decl_end - (p + 6));"
    "string_view decl(text.data() + static_cast<size_t>(p + 6 - text.begin()), static_cast<size_t>(decl_end - (p + 6)));"
    _OMEGA_XMLPARSER_CC "${_OMEGA_XMLPARSER_CC}")
  file(WRITE "${OMEGA_BINARY_DIR}/xmlparser.cc" "${_OMEGA_XMLPARSER_CC}")
  set(OMEGA_XMLPARSER_CC "${OMEGA_BINARY_DIR}/xmlparser.cc")
else()
  set(OMEGA_XMLPARSER_CC "${OMEGA_ROOT}/xmlparser.cc")
endif()

function(omega_common_includes target)
  target_include_directories(${target} PRIVATE
    "${OMEGA_BINARY_DIR}"
    "${OMEGA_ROOT}"
    "${OMEGA_ROOT}/common"
    ${OMEGA_MAGIC_INCLUDES})
  target_compile_definitions(${target} PRIVATE
    HAVE_CONFIG_H
    CONFIGFILE_SYSTEM=\"omega.conf\"
    PACKAGE_STRING=\"xapian-omega\ ${PROJECT_VERSION}\"
    PKGLIBBINDIR=\".\")
  if(WIN32)
    target_compile_definitions(${target} PRIVATE __WIN32__)
  endif()
endfunction()

# --- helper libs ---
add_library(omega_transform STATIC "${OMEGA_ROOT}/transform.cc")
omega_common_includes(omega_transform)
target_link_libraries(omega_transform PUBLIC ${OMEGA_PCRE_TARGET} Xapian::xapian)

add_library(omega_utf8convert STATIC "${OMEGA_ROOT}/utf8convert.cc")
omega_common_includes(omega_utf8convert)
target_link_libraries(omega_utf8convert PUBLIC Xapian::xapian)

# --- omega (CGI) ---
add_executable(omega
  "${OMEGA_ROOT}/omega.cc"
  "${OMEGA_ROOT}/query.cc"
  "${OMEGA_ROOT}/cgiparam.cc"
  "${OMEGA_ROOT}/utils.cc"
  "${OMEGA_ROOT}/configfile.cc"
  "${OMEGA_ROOT}/date.cc"
  "${OMEGA_ROOT}/cdb_init.cc"
  "${OMEGA_ROOT}/cdb_find.cc"
  "${OMEGA_ROOT}/cdb_hash.cc"
  "${OMEGA_ROOT}/jsonescape.cc"
  "${OMEGA_ROOT}/loadfile.cc"
  "${OMEGA_ROOT}/datevalue.cc"
  "${OMEGA_ROOT}/common/str.cc"
  "${OMEGA_ROOT}/sample.cc"
  "${OMEGA_ROOT}/sort.cc"
  "${OMEGA_ROOT}/urlencode.cc"
  "${OMEGA_ROOT}/weight.cc"
  "${OMEGA_ROOT}/expand.cc"
  "${OMEGA_ROOT}/csvescape.cc"
  "${OMEGA_ROOT}/timegm.cc"
  "${OMEGA_ROOT}/md5.cc"
  "${OMEGA_ROOT}/md5wrap.cc"
)
omega_common_includes(omega)
target_link_libraries(omega PRIVATE omega_transform Xapian::xapian)

# --- scriptindex ---
add_executable(scriptindex
  "${OMEGA_ROOT}/scriptindex.cc"
  "${OMEGA_ROOT}/genericxmlparser.cc"
  "${OMEGA_ROOT}/htmlparser.cc"
  "${OMEGA_XMLPARSER_CC}"
  "${OMEGA_ROOT}/common/getopt.cc"
  "${OMEGA_ROOT}/common/str.cc"
  "${OMEGA_ROOT}/commonhelp.cc"
  "${OMEGA_ROOT}/utils.cc"
  "${OMEGA_ROOT}/hashterm.cc"
  "${OMEGA_ROOT}/loadfile.cc"
  "${OMEGA_ROOT}/utf8truncate.cc"
  "${OMEGA_ROOT}/common/keyword.cc"
  "${OMEGA_ROOT}/strptime.cc"
  "${OMEGA_ROOT}/timegm.cc"
  "${OMEGA_ROOT}/datetime.cc"
)
omega_common_includes(scriptindex)
target_link_libraries(scriptindex PRIVATE omega_utf8convert Xapian::xapian)

# --- omindex-list ---
add_executable(omindex-list
  "${OMEGA_ROOT}/common/getopt.cc"
  "${OMEGA_ROOT}/omindex-list.cc"
)
omega_common_includes(omindex-list)
target_link_libraries(omindex-list PRIVATE Xapian::xapian)

# --- omindex ---
set(OMINDEX_SOURCES
  "${OMEGA_ROOT}/omindex.cc"
  "${OMEGA_ROOT}/htmlparser.cc"
  "${OMEGA_XMLPARSER_CC}"
  "${OMEGA_ROOT}/index_file.cc"
  "${OMEGA_ROOT}/mime.cc"
  "${OMEGA_ROOT}/common/getopt.cc"
  "${OMEGA_ROOT}/commonhelp.cc"
  "${OMEGA_ROOT}/utils.cc"
  "${OMEGA_ROOT}/hashterm.cc"
  "${OMEGA_ROOT}/loadfile.cc"
  "${OMEGA_ROOT}/md5.cc"
  "${OMEGA_ROOT}/md5wrap.cc"
  "${OMEGA_ROOT}/abiwordparser.cc"
  "${OMEGA_ROOT}/gnumericparser.cc"
  "${OMEGA_ROOT}/opendocmetaparser.cc"
  "${OMEGA_ROOT}/sample.cc"
  "${OMEGA_ROOT}/diritor.cc"
  "${OMEGA_ROOT}/runfilter.cc"
  "${OMEGA_ROOT}/freemem.cc"
  "${OMEGA_ROOT}/xpsparser.cc"
  "${OMEGA_ROOT}/common/str.cc"
  "${OMEGA_ROOT}/pkglibbindir.cc"
  "${OMEGA_ROOT}/svgparser.cc"
  "${OMEGA_ROOT}/tmpdir.cc"
  "${OMEGA_ROOT}/urlencode.cc"
  "${OMEGA_ROOT}/atomparser.cc"
  "${OMEGA_ROOT}/xlsxparser.cc"
  "${OMEGA_ROOT}/opendocparser.cc"
  "${OMEGA_ROOT}/common/keyword.cc"
  "${OMEGA_ROOT}/msxmlparser.cc"
  "${OMEGA_ROOT}/common/safe.cc"
  "${OMEGA_ROOT}/mkdtemp.cc"
  "${OMEGA_ROOT}/strptime.cc"
  "${OMEGA_ROOT}/timegm.cc"
  "${OMEGA_ROOT}/datetime.cc"
  "${OMEGA_ROOT}/common/closefrom.cc"
  "${OMEGA_ROOT}/worker.cc"
  "${OMEGA_ROOT}/worker_comms.cc"
)
if(WIN32)
  list(APPEND OMINDEX_SOURCES "${OMEGA_ROOT}/common/msvc_dirent.cc")
endif()
if(OMEGA_USE_MAGIC_STUB)
  list(APPEND OMINDEX_SOURCES "${OMEGA_MAGIC_STUB_SRC}")
endif()

add_executable(omindex ${OMINDEX_SOURCES})
omega_common_includes(omindex)
target_link_libraries(omindex PRIVATE omega_utf8convert Xapian::xapian ${XAPIAN_ZLIB_TARGET})
if(OMEGA_MAGIC_LIBS)
  target_link_libraries(omindex PRIVATE ${OMEGA_MAGIC_LIBS})
endif()
if(WIN32)
  target_link_libraries(omindex PRIVATE ws2_32)
endif()

# Smoke: scriptindex --help / omindex --version style where available
enable_testing()
add_test(NAME omega-scriptindex-help COMMAND scriptindex --help)
set_tests_properties(omega-scriptindex-help PROPERTIES PASS_REGULAR_EXPRESSION ".")

install(TARGETS omega scriptindex omindex omindex-list RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
