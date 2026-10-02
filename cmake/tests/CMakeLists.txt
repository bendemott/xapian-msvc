# Upstream xapian-core testsuite (easy subset: local backends only).
# Expects XAPIAN_SOURCE_ROOT, Xapian::xapian, and the generated config.h.

set(TESTS_SRC "${XAPIAN_SOURCE_ROOT}/tests")
set(TESTS_COMMON "${XAPIAN_SOURCE_ROOT}/common")

if(NOT TARGET xapian_getopt)
  add_library(xapian_getopt STATIC "${TESTS_COMMON}/getopt.cc")
  target_include_directories(xapian_getopt PUBLIC
    "${TESTS_COMMON}"
    "${CMAKE_BINARY_DIR}"
  )
  target_compile_definitions(xapian_getopt PRIVATE HAVE_CONFIG_H)
  if(DEFINED XAPIAN_ZLIB_TARGET)
    target_link_libraries(xapian_getopt PUBLIC ${XAPIAN_ZLIB_TARGET})
  endif()
endif()

# --- harness (shared by apitest / stemtest / internaltest) ---
set(HARNESS_SOURCES
  "${TESTS_COMMON}/errno_to_string.cc"
  "${TESTS_COMMON}/str.cc"
  "${TESTS_SRC}/harness/backendmanager.cc"
  "${TESTS_SRC}/harness/backendmanager_multi.cc"
  "${TESTS_SRC}/harness/cputimer.cc"
  "${TESTS_SRC}/harness/fdtracker.cc"
  "${TESTS_SRC}/harness/index_utils.cc"
  "${TESTS_SRC}/harness/scalability.cc"
  "${TESTS_SRC}/harness/testrunner.cc"
  "${TESTS_SRC}/harness/testsuite.cc"
  "${TESTS_SRC}/harness/testutils.cc"
  "${TESTS_SRC}/harness/unixcmds.cc"
)
if(XAPIAN_ENABLE_BACKEND_GLASS)
  list(APPEND HARNESS_SOURCES
    "${TESTS_SRC}/harness/backendmanager_glass.cc"
    "${TESTS_SRC}/harness/backendmanager_singlefile.cc"
  )
endif()
if(XAPIAN_ENABLE_BACKEND_HONEY)
  list(APPEND HARNESS_SOURCES
    "${TESTS_SRC}/harness/backendmanager_honey.cc"
  )
endif()
if(XAPIAN_ENABLE_BACKEND_INMEMORY)
  list(APPEND HARNESS_SOURCES
    "${TESTS_SRC}/harness/backendmanager_inmemory.cc"
  )
endif()
# Remote managers are referenced from testrunner.cc when remote is enabled;
# we still build them so the harness links, but CTest only runs local -b flags.
if(XAPIAN_ENABLE_BACKEND_REMOTE)
  list(APPEND HARNESS_SOURCES
    "${TESTS_SRC}/harness/backendmanager_remote.cc"
    "${TESTS_SRC}/harness/backendmanager_remoteprog.cc"
    "${TESTS_SRC}/harness/backendmanager_remotetcp.cc"
  )
endif()

add_library(xapian_testharness STATIC ${HARNESS_SOURCES})
target_include_directories(xapian_testharness PUBLIC
  "${TESTS_SRC}"
  "${TESTS_SRC}/harness"
  "${TESTS_COMMON}"
  "${XAPIAN_SOURCE_ROOT}"
  "${XAPIAN_SOURCE_ROOT}/include"
  "${CMAKE_BINARY_DIR}"
  "${CMAKE_BINARY_DIR}/include"
)
target_compile_definitions(xapian_testharness PUBLIC HAVE_CONFIG_H)
target_link_libraries(xapian_testharness PUBLIC Xapian::xapian xapian_getopt)
if(MSVC)
  target_compile_options(xapian_testharness PRIVATE /W3 /EHsc /bigobj /wd4003 /wd4267 /wd4244 /wd4996)
endif()

# --- apitest ---
set(APITEST_SOURCES
  "${TESTS_SRC}/apitest.cc"
  "${TESTS_SRC}/dbcheck.cc"
  "${TESTS_SRC}/api_anydb.cc"
  "${TESTS_SRC}/api_backend.cc"
  "${TESTS_SRC}/api_closedb.cc"
  "${TESTS_SRC}/api_collapse.cc"
  "${TESTS_SRC}/api_compact.cc"
  "${TESTS_SRC}/api_db.cc"
  "${TESTS_SRC}/api_generated.cc"
  "${TESTS_SRC}/api_geospatial.cc"
  "${TESTS_SRC}/api_matchspy.cc"
  "${TESTS_SRC}/api_metadata.cc"
  "${TESTS_SRC}/api_nodb.cc"
  "${TESTS_SRC}/api_none.cc"
  "${TESTS_SRC}/api_opsynonym.cc"
  "${TESTS_SRC}/api_opvalue.cc"
  "${TESTS_SRC}/api_percentages.cc"
  "${TESTS_SRC}/api_posdb.cc"
  "${TESTS_SRC}/api_postingsource.cc"
  "${TESTS_SRC}/api_qpbackend.cc"
  "${TESTS_SRC}/api_query.cc"
  "${TESTS_SRC}/api_queryopt.cc"
  "${TESTS_SRC}/api_queryparser.cc"
  "${TESTS_SRC}/api_replacedoc.cc"
  "${TESTS_SRC}/api_replicate.cc"
  "${TESTS_SRC}/api_scalability.cc"
  "${TESTS_SRC}/api_serialise.cc"
  "${TESTS_SRC}/api_snippets.cc"
  "${TESTS_SRC}/api_sorting.cc"
  "${TESTS_SRC}/api_spelling.cc"
  "${TESTS_SRC}/api_stem.cc"
  "${TESTS_SRC}/api_termgen.cc"
  "${TESTS_SRC}/api_transdb.cc"
  "${TESTS_SRC}/api_unicode.cc"
  "${TESTS_SRC}/api_valuestats.cc"
  "${TESTS_SRC}/api_valuestream.cc"
  "${TESTS_SRC}/api_weight.cc"
  "${TESTS_SRC}/api_wrdb.cc"
)

add_executable(apitest ${APITEST_SOURCES})
target_link_libraries(apitest PRIVATE xapian_testharness)
if(MSVC)
  target_compile_options(apitest PRIVATE /W3 /EHsc /bigobj /wd4003 /wd4267 /wd4244 /wd4996)
endif()

add_executable(stemtest "${TESTS_SRC}/stemtest.cc")
target_link_libraries(stemtest PRIVATE xapian_testharness)
if(MSVC)
  target_compile_options(stemtest PRIVATE /W3 /EHsc /bigobj /wd4003 /wd4267 /wd4244 /wd4996)
endif()

add_executable(internaltest "${TESTS_SRC}/internaltest.cc")
target_link_libraries(internaltest PRIVATE xapian_testharness)
if(MSVC)
  target_compile_options(internaltest PRIVATE /W3 /EHsc /bigobj /wd4003 /wd4267 /wd4244 /wd4996)
endif()

# unittest pulls many library .cc files via #include — try it; may need tweaks.
add_executable(unittest
  "${TESTS_SRC}/unittest.cc"
  "${TESTS_SRC}/harness/fdtracker.cc"
  "${TESTS_SRC}/harness/utestsuite.cc"
)
target_include_directories(unittest PRIVATE
  "${TESTS_SRC}"
  "${TESTS_SRC}/harness"
  "${TESTS_COMMON}"
  "${XAPIAN_SOURCE_ROOT}"
  "${XAPIAN_SOURCE_ROOT}/include"
  "${CMAKE_BINARY_DIR}"
  "${CMAKE_BINARY_DIR}/include"
)
target_compile_definitions(unittest PRIVATE HAVE_CONFIG_H NO_LIBXAPIAN)
target_link_libraries(unittest PRIVATE xapian_getopt ${XAPIAN_ZLIB_TARGET})
if(WIN32)
  target_link_libraries(unittest PRIVATE ws2_32 rpcrt4)
endif()
if(MSVC)
  target_compile_options(unittest PRIVATE /W3 /EHsc /bigobj /wd4003 /wd4267 /wd4244 /wd4996)
endif()

# Writable dir for cached backend DBs created during tests.
set(TEST_WORKDIR "${CMAKE_CURRENT_BINARY_DIR}/workdir")
file(MAKE_DIRECTORY "${TEST_WORKDIR}")
file(TO_CMAKE_PATH "${TESTS_SRC}" XAPIAN_TEST_SRCDIR)

enable_testing()

function(xapian_add_ctest name command)
  cmake_parse_arguments(T "" "" "ARGS" ${ARGN})
  add_test(
    NAME ${name}
    COMMAND ${command} ${T_ARGS}
    WORKING_DIRECTORY "${TEST_WORKDIR}"
  )
  set_tests_properties(${name} PROPERTIES
    ENVIRONMENT "srcdir=${XAPIAN_TEST_SRCDIR}"
    TIMEOUT 600
  )
endfunction()

# Easy local backends only. multi_glass is omitted because apitest's -b matching
# treats it as a prefix and also runs multi_glass_remoteprog_glass (needs remote).
# singlefile omitted (stub/compact path issues). A few compact*/stubdb cases are
# SKIP'd under _MSC_VER until path/remote tooling is fixed.
xapian_add_ctest(apitest-none apitest ARGS -b none)
if(XAPIAN_ENABLE_BACKEND_INMEMORY)
  xapian_add_ctest(apitest-inmemory apitest ARGS -b inmemory)
endif()
if(XAPIAN_ENABLE_BACKEND_GLASS)
  xapian_add_ctest(apitest-glass apitest ARGS -b glass)
endif()
if(XAPIAN_ENABLE_BACKEND_HONEY)
  xapian_add_ctest(apitest-honey apitest ARGS -b honey)
endif()

xapian_add_ctest(stemtest stemtest)
xapian_add_ctest(internaltest internaltest)
xapian_add_ctest(unittest unittest)
