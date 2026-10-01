cmake_minimum_required(VERSION 3.20)
project(xapian-core VERSION 2.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(XAPIAN_ENABLE_BACKEND_GLASS "Enable glass backend" ON)
option(XAPIAN_ENABLE_BACKEND_HONEY "Enable honey backend" ON)
option(XAPIAN_ENABLE_BACKEND_INMEMORY "Enable inmemory backend" ON)
option(XAPIAN_ENABLE_BACKEND_REMOTE "Enable remote backend" ON)
option(XAPIAN_USE_ICU "Enable ICU word-breaking" OFF)
option(XAPIAN_BUILD_SMOKE_TEST "Build smoke test executable" ON)
option(XAPIAN_USE_VISIBILITY "Use ELF visibility attributes (GCC/Clang)" ON)

# Prefer a local import; otherwise FetchContent the official release tarball.
set(XAPIAN_SOURCE_ROOT "${CMAKE_SOURCE_DIR}/third_party/xapian-core" CACHE PATH
    "Path to xapian-core sources")

if(NOT EXISTS "${XAPIAN_SOURCE_ROOT}/include/xapian.h")
  include(FetchContent)
  set(XAPIAN_FETCH_VERSION "${PROJECT_VERSION}")
  message(STATUS "xapian-core not at ${XAPIAN_SOURCE_ROOT}; downloading ${XAPIAN_FETCH_VERSION}")
  FetchContent_Declare(
    xapian_core_src
    URL "https://oligarchy.co.uk/xapian/${XAPIAN_FETCH_VERSION}/xapian-core-${XAPIAN_FETCH_VERSION}.tar.xz"
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  )
  FetchContent_GetProperties(xapian_core_src)
  if(NOT xapian_core_src_POPULATED)
    FetchContent_Populate(xapian_core_src)
  endif()
  set(XAPIAN_SOURCE_ROOT "${xapian_core_src_SOURCE_DIR}" CACHE PATH "Path to xapian-core sources" FORCE)
endif()

if(NOT EXISTS "${XAPIAN_SOURCE_ROOT}/include/xapian.h")
  message(FATAL_ERROR "xapian-core sources not found. Run ./scripts/import-xapian-core.sh ${PROJECT_VERSION}")
endif()

find_package(ZLIB)
if(NOT ZLIB_FOUND)
  message(STATUS "ZLIB not found; fetching zlib via FetchContent")
  include(FetchContent)
  FetchContent_Declare(
    zlib
    URL https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  )
  set(ZLIB_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(zlib)
  if(NOT TARGET ZLIB::ZLIB)
    add_library(ZLIB::ZLIB ALIAS zlib)
  endif()
endif()
if(XAPIAN_USE_ICU)
  find_package(ICU REQUIRED COMPONENTS uc i18n)
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(XapianFeatureChecks)
xapian_detect_features()

if(XAPIAN_USE_ICU)
  set(USE_ICU 1)
endif()

# Public version.h type mapping (matches typical upstream configure results).
set(XAPIAN_DOCID_BASE_TYPE int)
set(XAPIAN_TERMCOUNT_BASE_TYPE int)
set(XAPIAN_TERMPOS_BASE_TYPE int)
if(SIZEOF_LONG EQUAL 8)
  set(XAPIAN_REVISION_TYPE "unsigned long")
else()
  set(XAPIAN_REVISION_TYPE "unsigned long long")
endif()

set(XAPIAN_HAS_GLASS_BACKEND ${XAPIAN_ENABLE_BACKEND_GLASS})
set(XAPIAN_HAS_HONEY_BACKEND ${XAPIAN_ENABLE_BACKEND_HONEY})
set(XAPIAN_HAS_INMEMORY_BACKEND ${XAPIAN_ENABLE_BACKEND_INMEMORY})
set(XAPIAN_HAS_REMOTE_BACKEND ${XAPIAN_ENABLE_BACKEND_REMOTE})

if(XAPIAN_USE_VISIBILITY AND NOT MSVC AND NOT WIN32)
  set(XAPIAN_ENABLE_VISIBILITY 1)
else()
  unset(XAPIAN_ENABLE_VISIBILITY)
endif()

if(MSVC AND CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(XAPIAN_CMAKE_LIBRARY_DEBUG 1)
endif()

configure_file(
  "${CMAKE_SOURCE_DIR}/cmake/config.h.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/config.h"
  @ONLY)

configure_file(
  "${CMAKE_SOURCE_DIR}/cmake/version.h.in"
  "${CMAKE_CURRENT_BINARY_DIR}/include/xapian/version.h"
  @ONLY)

# Override visibility.h for DLL-friendly MSVC builds.
configure_file(
  "${CMAKE_SOURCE_DIR}/cmake/visibility.h"
  "${CMAKE_CURRENT_BINARY_DIR}/include/xapian/visibility.h"
  COPYONLY)

include("${CMAKE_SOURCE_DIR}/cmake/xapian_core_sources.cmake")
set(XAPIAN_CORE_SOURCES)
foreach(rel ${XAPIAN_CORE_RELATIVE_SOURCES})
  list(APPEND XAPIAN_CORE_SOURCES "${XAPIAN_SOURCE_ROOT}/${rel}")
endforeach()

# Remote-related sources are already in the extracted list for the default
# all-backends configuration. If remote is disabled, strip remote files.
if(NOT XAPIAN_ENABLE_BACKEND_REMOTE)
  list(FILTER XAPIAN_CORE_SOURCES EXCLUDE REGEX ".*/(net/|backends/remote/|dbfactory_remote\\.cc|replication\\.cc|databasereplicator\\.cc|glass_databasereplicator\\.cc|socket_utils\\.cc|replicate_utils\\.cc)")
endif()
if(NOT XAPIAN_ENABLE_BACKEND_GLASS)
  list(FILTER XAPIAN_CORE_SOURCES EXCLUDE REGEX ".*/backends/glass/")
endif()
if(NOT XAPIAN_ENABLE_BACKEND_HONEY)
  list(FILTER XAPIAN_CORE_SOURCES EXCLUDE REGEX ".*/backends/honey/")
endif()
if(NOT XAPIAN_ENABLE_BACKEND_INMEMORY)
  list(FILTER XAPIAN_CORE_SOURCES EXCLUDE REGEX ".*/backends/inmemory/")
endif()

add_library(xapian ${XAPIAN_CORE_SOURCES})
add_library(Xapian::xapian ALIAS xapian)
set_target_properties(xapian PROPERTIES OUTPUT_NAME xapian)

target_compile_definitions(xapian
  PRIVATE
    HAVE_CONFIG_H
    XAPIAN_LIB_BUILD
    $<$<BOOL:${BUILD_SHARED_LIBS}>:XAPIAN_BUILD_DLL>
  PUBLIC
    $<$<BOOL:${BUILD_SHARED_LIBS}>:XAPIAN_BUILD_DLL>
)

target_include_directories(xapian
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
    $<BUILD_INTERFACE:${XAPIAN_SOURCE_ROOT}/include>
    $<INSTALL_INTERFACE:include>
  PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}"
    "${XAPIAN_SOURCE_ROOT}"
    "${XAPIAN_SOURCE_ROOT}/common"
    "${XAPIAN_SOURCE_ROOT}/include"
)

target_link_libraries(xapian PUBLIC ZLIB::ZLIB)

if(WIN32)
  target_link_libraries(xapian PRIVATE ws2_32 rpcrt4)
else()
  # UUID: prefer libuuid when uuid/uuid.h was found
  if(HAVE_UUID_UUID_H)
    find_library(UUID_LIBRARY uuid)
    if(UUID_LIBRARY)
      target_link_libraries(xapian PRIVATE ${UUID_LIBRARY})
    endif()
  endif()
endif()

if(XAPIAN_USE_ICU)
  target_link_libraries(xapian PRIVATE ICU::uc ICU::i18n)
endif()

if(DEFINED XAPIAN_ENABLE_VISIBILITY)
  target_compile_options(xapian PRIVATE -fvisibility=hidden -fvisibility-inlines-hidden)
endif()

if(MSVC)
  target_compile_options(xapian PRIVATE /W3 /EHsc /bigobj)
else()
  target_compile_options(xapian PRIVATE -Wall -Wno-unused)
endif()

if(XAPIAN_BUILD_SMOKE_TEST)
  add_executable(xapian-cmake-smoke examples/smoke_test.cpp)
  target_link_libraries(xapian-cmake-smoke PRIVATE Xapian::xapian)
  enable_testing()
  add_test(NAME smoke COMMAND xapian-cmake-smoke)
endif()

include(GNUInstallDirs)
install(TARGETS xapian
  EXPORT XapianTargets
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY "${XAPIAN_SOURCE_ROOT}/include/xapian"
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
  FILES_MATCHING PATTERN "*.h"
  PATTERN "version_h.cc" EXCLUDE
  PATTERN "visibility.h" EXCLUDE
  PATTERN "version.h" EXCLUDE)
install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/include/xapian/version.h"
  "${CMAKE_CURRENT_BINARY_DIR}/include/xapian/visibility.h"
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/xapian)
install(FILES "${XAPIAN_SOURCE_ROOT}/include/xapian.h"
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
