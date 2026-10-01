# Illustrative CMake skeleton for an MSVC-native xapian-core build.
# This is NOT a complete port — it documents the shape of the work.
#
# Expected layout after running scripts/import-xapian-core.sh:
#   third_party/xapian-core/   (upstream release sources)
#   cmake/skeleton/            (this file — copy or include from repo root)
#
# Usage (once sources are imported and source lists filled in):
#   cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
#   cmake --build build

cmake_minimum_required(VERSION 3.20)
project(xapian-core-msvc-skeleton VERSION 2.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(XAPIAN_ENABLE_BACKEND_GLASS "Glass backend" ON)
option(XAPIAN_ENABLE_BACKEND_HONEY "Honey backend" ON)
option(XAPIAN_ENABLE_BACKEND_INMEMORY "Inmemory backend" ON)
option(XAPIAN_ENABLE_BACKEND_REMOTE "Remote backend" ON)
option(XAPIAN_USE_ICU "ICU word-breaking support" OFF)

# Point at an imported release tree (see scripts/import-xapian-core.sh).
set(XAPIAN_SOURCE_ROOT "${CMAKE_SOURCE_DIR}/third_party/xapian-core"
    CACHE PATH "Path to xapian-core sources")

if(NOT EXISTS "${XAPIAN_SOURCE_ROOT}/include/xapian.h")
  message(FATAL_ERROR
    "xapian-core sources not found at ${XAPIAN_SOURCE_ROOT}.\n"
    "Run: ./scripts/import-xapian-core.sh 2.1.0")
endif()

find_package(ZLIB REQUIRED)
if(XAPIAN_USE_ICU)
  find_package(ICU REQUIRED COMPONENTS uc i18n)
endif()

include(CheckIncludeFileCXX)
include(CheckCXXSourceCompiles)
include(CheckTypeSize)
include(CheckSymbolExists)

# --- Feature probes (subset; expand from config.h.in as needed) ---
check_include_file_cxx("unistd.h" HAVE_UNISTD_H)
check_include_file_cxx("sys/stat.h" HAVE_SYS_STAT_H)
check_type_size("short" SIZEOF_SHORT)
check_type_size("int" SIZEOF_INT)
check_type_size("long" SIZEOF_LONG)
check_type_size("long long" SIZEOF_LONG_LONG)

if(WIN32)
  set(HAVE_FORK 0)
  set(USE_WIN32_UUID_API 1)
  set(HAVE_ZLIB_H 1)
else()
  check_symbol_exists(fork "unistd.h" HAVE_FORK)
  set(USE_WIN32_UUID_API 0)
endif()

# Backend enables → public version.h macros
set(XAPIAN_HAS_GLASS_BACKEND ${XAPIAN_ENABLE_BACKEND_GLASS})
set(XAPIAN_HAS_HONEY_BACKEND ${XAPIAN_ENABLE_BACKEND_HONEY})
set(XAPIAN_HAS_INMEMORY_BACKEND ${XAPIAN_ENABLE_BACKEND_INMEMORY})
set(XAPIAN_HAS_REMOTE_BACKEND ${XAPIAN_ENABLE_BACKEND_REMOTE})

# Integer base types — match upstream defaults for LP64 / LLP64
if(SIZEOF_INT EQUAL 4)
  set(XAPIAN_DOCID_BASE_TYPE int)
  set(XAPIAN_TERMCOUNT_BASE_TYPE int)
  set(XAPIAN_TERMPOS_BASE_TYPE int)
else()
  message(FATAL_ERROR "Unexpected sizeof(int); adjust type mapping")
endif()
if(SIZEOF_LONG_LONG EQUAL 8)
  set(XAPIAN_REVISION_TYPE "unsigned long long")
else()
  set(XAPIAN_REVISION_TYPE "unsigned long")
endif()

set(PACKAGE "xapian-core")
set(PACKAGE_VERSION "${PROJECT_VERSION}")
set(VERSION "${PROJECT_VERSION}")
set(STRING_VERSION "\"${PROJECT_VERSION}\"")
set(MAJOR_VERSION ${PROJECT_VERSION_MAJOR})
set(MINOR_VERSION ${PROJECT_VERSION_MINOR})
set(REVISION ${PROJECT_VERSION_PATCH})

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/config.h.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/config.h"
  @ONLY)

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/version.h.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/include/xapian/version.h"
  @ONLY)

# --- Sources ---
# TODO: replace with the full lib_src list extracted from Automake.
# Start from third_party/xapian-core/*/Makefile.mk "lib_src +=" entries.
set(XAPIAN_LIB_SOURCES
  # Placeholder — fill from Automake before this target will link.
  # Example entries:
  # ${XAPIAN_SOURCE_ROOT}/api/database.cc
  # ${XAPIAN_SOURCE_ROOT}/api/document.cc
  # ...
)

if(WIN32)
  list(APPEND XAPIAN_LIB_SOURCES
    "${XAPIAN_SOURCE_ROOT}/common/msvc_dirent.cc")
endif()

if(NOT XAPIAN_LIB_SOURCES)
  message(WARNING
    "XAPIAN_LIB_SOURCES is empty — skeleton only. "
    "Extract lib_src from Makefile.mk files before building.")
  return()
endif()

add_library(xapian ${XAPIAN_LIB_SOURCES})
add_library(Xapian::xapian ALIAS xapian)

target_compile_definitions(xapian
  PRIVATE
    HAVE_CONFIG_H
    XAPIAN_LIB_BUILD
    PACKAGE="${PACKAGE}"
  PUBLIC
    $<$<BOOL:${BUILD_SHARED_LIBS}>:XAPIAN_BUILD_DLL>
)

target_include_directories(xapian
  PUBLIC
    $<BUILD_INTERFACE:${XAPIAN_SOURCE_ROOT}/include>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
    $<INSTALL_INTERFACE:include>
  PRIVATE
    "${XAPIAN_SOURCE_ROOT}/common"
    "${XAPIAN_SOURCE_ROOT}"
    "${CMAKE_CURRENT_BINARY_DIR}"
)

target_link_libraries(xapian PUBLIC ZLIB::ZLIB)
if(WIN32)
  target_link_libraries(xapian PRIVATE ws2_32 rpcrt4)
endif()
if(XAPIAN_USE_ICU)
  target_link_libraries(xapian PRIVATE ICU::uc ICU::i18n)
  target_compile_definitions(xapian PRIVATE USE_ICU)
endif()

if(MSVC)
  target_compile_options(xapian PRIVATE /W3 /EHsc)
  # Match upstream desire to avoid noisy secure-CRT deprecations via config.h.
endif()

install(TARGETS xapian EXPORT XapianTargets
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin)
install(DIRECTORY "${XAPIAN_SOURCE_ROOT}/include/xapian"
  DESTINATION include
  FILES_MATCHING PATTERN "*.h")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/include/xapian/version.h"
  DESTINATION include/xapian)
