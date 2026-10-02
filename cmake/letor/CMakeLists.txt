# xapian-letor (Learning to Rank) — CMake build for MSVC / Ninja.
# Sources come from the xapian git monorepo (not a separate release tarball).

set(LETOR_ROOT "${CMAKE_SOURCE_DIR}/third_party/xapian-letor" CACHE PATH
    "Path to xapian-letor sources")

if(NOT EXISTS "${LETOR_ROOT}/include/xapian-letor.h")
  include(FetchContent)
  message(STATUS "xapian-letor not at ${LETOR_ROOT}; downloading from GitHub tag v${PROJECT_VERSION}")
  FetchContent_Declare(
    xapian_letor_src
    URL "https://codeload.github.com/xapian/xapian/tar.gz/v${PROJECT_VERSION}"
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  )
  FetchContent_MakeAvailable(xapian_letor_src)
  if(DEFINED xapian_letor_src_SOURCE_DIR AND EXISTS "${xapian_letor_src_SOURCE_DIR}/xapian-letor/include/xapian-letor.h")
    # Full monorepo tarball — point at the letor subdirectory.
    set(LETOR_ROOT "${xapian_letor_src_SOURCE_DIR}/xapian-letor" CACHE PATH
        "Path to xapian-letor sources" FORCE)
  endif()
endif()

if(NOT EXISTS "${LETOR_ROOT}/include/xapian-letor.h")
  message(FATAL_ERROR "xapian-letor sources not found. Run: python scripts/import-xapian.py letor")
endif()

set(XAPIAN_CORE_COMMON "${XAPIAN_SOURCE_ROOT}/common")
if(NOT EXISTS "${XAPIAN_CORE_COMMON}/str.cc")
  message(FATAL_ERROR "xapian-core common/ not found at ${XAPIAN_CORE_COMMON}")
endif()

# Generated exception headers (git tree does not ship them; release tarballs would).
set(LETOR_GEN_INCLUDE "${CMAKE_CURRENT_BINARY_DIR}/include")
file(MAKE_DIRECTORY "${LETOR_GEN_INCLUDE}/xapian-letor")
find_package(Python3 COMPONENTS Interpreter REQUIRED)
execute_process(
  COMMAND ${Python3_EXECUTABLE}
    "${CMAKE_SOURCE_DIR}/scripts/generate-letor-exceptions.py"
    --outdir "${LETOR_GEN_INCLUDE}/xapian-letor"
  RESULT_VARIABLE _letor_gen_rc
)
if(NOT _letor_gen_rc EQUAL 0)
  message(FATAL_ERROR "Failed to generate letor_error.h")
endif()

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/config.h.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/config.h"
  @ONLY)

set(LETOR_SOURCES
  "${LETOR_ROOT}/api/feature_internal.cc"
  "${LETOR_ROOT}/api/featurelist.cc"
  "${LETOR_ROOT}/api/featurelist_internal.cc"
  "${LETOR_ROOT}/api/featurevector.cc"
  "${LETOR_ROOT}/feature/colltfcolllenfeature.cc"
  "${LETOR_ROOT}/feature/feature.cc"
  "${LETOR_ROOT}/feature/idffeature.cc"
  "${LETOR_ROOT}/feature/tfdoclencolltfcolllenfeature.cc"
  "${LETOR_ROOT}/feature/tfdoclenfeature.cc"
  "${LETOR_ROOT}/feature/tfidfdoclenfeature.cc"
  "${LETOR_ROOT}/feature/tffeature.cc"
  "${LETOR_ROOT}/ranker/listmle_ranker.cc"
  "${LETOR_ROOT}/ranker/listnet_ranker.cc"
  "${LETOR_ROOT}/ranker/ranker.cc"
  "${LETOR_ROOT}/scorer/err_score.cc"
  "${LETOR_ROOT}/scorer/ndcg_score.cc"
  "${XAPIAN_CORE_COMMON}/str.cc"
  "${XAPIAN_CORE_COMMON}/serialise-double.cc"
)

add_library(xapianletor ${LETOR_SOURCES})
add_library(Xapian::letor ALIAS xapianletor)
set_target_properties(xapianletor PROPERTIES
  OUTPUT_NAME xapianletor
  EXPORT_NAME letor)

target_compile_definitions(xapianletor PRIVATE HAVE_CONFIG_H XAPIAN_LIB_BUILD)
target_include_directories(xapianletor
  PUBLIC
    $<BUILD_INTERFACE:${LETOR_GEN_INCLUDE}>
    $<BUILD_INTERFACE:${LETOR_ROOT}/include>
    $<INSTALL_INTERFACE:include>
  PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}"
    "${LETOR_ROOT}"
    "${LETOR_ROOT}/api"
    "${XAPIAN_CORE_COMMON}"
)

target_link_libraries(xapianletor PUBLIC Xapian::xapian)

if(MSVC)
  target_compile_options(xapianletor PRIVATE /W3 /EHsc /bigobj /wd4003 /wd4267 /wd4244)
else()
  target_compile_options(xapianletor PRIVATE -Wall -Wno-unused)
endif()

if(XAPIAN_BUILD_SMOKE_TEST)
  add_executable(xapian-letor-smoke "${CMAKE_SOURCE_DIR}/examples/letor_smoke.cpp")
  target_link_libraries(xapian-letor-smoke PRIVATE Xapian::letor)
  enable_testing()
  add_test(NAME letor-smoke COMMAND xapian-letor-smoke)
endif()

include(GNUInstallDirs)
install(TARGETS xapianletor
  EXPORT XapianTargets
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY "${LETOR_ROOT}/include/"
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
  FILES_MATCHING PATTERN "*.h"
  PATTERN "letor_error.h" EXCLUDE
  PATTERN "letor_errordispatch.h" EXCLUDE)
install(FILES
  "${LETOR_GEN_INCLUDE}/xapian-letor/letor_error.h"
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/xapian-letor)
