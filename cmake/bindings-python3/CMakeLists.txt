# Python 3 bindings for Xapian (pre-generated SWIG wrap from the release tarball).
# Expects Xapian::xapian from the parent project.

set(BINDINGS_ROOT "${CMAKE_SOURCE_DIR}/third_party/xapian-bindings" CACHE PATH
    "Path to xapian-bindings sources")

if(NOT EXISTS "${BINDINGS_ROOT}/python3/xapian_wrap.cc")
  include(FetchContent)
  message(STATUS "xapian-bindings not at ${BINDINGS_ROOT}; downloading ${PROJECT_VERSION}")
  FetchContent_Declare(
    xapian_bindings_src
    URL "https://oligarchy.co.uk/xapian/${PROJECT_VERSION}/xapian-bindings-${PROJECT_VERSION}.tar.xz"
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  )
  FetchContent_MakeAvailable(xapian_bindings_src)
  set(BINDINGS_ROOT "${xapian_bindings_src_SOURCE_DIR}" CACHE PATH
      "Path to xapian-bindings sources" FORCE)
endif()

set(PY3_SRC "${BINDINGS_ROOT}/python3")
if(NOT EXISTS "${PY3_SRC}/xapian_wrap.cc")
  message(FATAL_ERROR "xapian-bindings python3 wrap not found. Run: python scripts/import-xapian.py bindings")
endif()

find_package(Python3 COMPONENTS Interpreter Development.Module REQUIRED)

# Shadow config.h ahead of the core one so MSVC + Python.h can coexist.
set(XAPIAN_CORE_CONFIG_H "${CMAKE_BINARY_DIR}/config.h")
file(TO_CMAKE_PATH "${XAPIAN_CORE_CONFIG_H}" XAPIAN_CORE_CONFIG_H)
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/config.h.in"
  "${CMAKE_CURRENT_BINARY_DIR}/config.h"
  @ONLY)

add_library(xapian_python3 MODULE "${PY3_SRC}/xapian_wrap.cc")
set_target_properties(xapian_python3 PROPERTIES
  OUTPUT_NAME "_xapian"
  PREFIX ""
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/python3/xapian"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/python3/xapian"
)
if(WIN32)
  set_target_properties(xapian_python3 PROPERTIES SUFFIX ".pyd")
endif()

# xapian_wrap.cc starts with #include <config.h> (same as the library build).
target_compile_definitions(xapian_python3 PRIVATE HAVE_CONFIG_H)
target_include_directories(xapian_python3 PRIVATE
  "${CMAKE_CURRENT_BINARY_DIR}"
  "${PY3_SRC}"
  ${Python3_INCLUDE_DIRS}
)
target_link_libraries(xapian_python3 PRIVATE Xapian::xapian Python3::Module)
# Core config.h includes <zlib.h> before redefining off_t. That include path
# is private to the xapian target, so the wrap needs zlib's own usage
# requirements (and the static library, when xapian itself is static).
if(DEFINED XAPIAN_ZLIB_TARGET AND TARGET "${XAPIAN_ZLIB_TARGET}")
  target_link_libraries(xapian_python3 PRIVATE "${XAPIAN_ZLIB_TARGET}")
endif()
if(MSVC)
  target_compile_options(xapian_python3 PRIVATE /bigobj /EHsc /wd4003 /wd4267 /wd4244 /wd4996)
endif()

# Package layout: build/python3/xapian/{__init__.py,_xapian.*}
set(PY_PKG_DIR "${CMAKE_BINARY_DIR}/python3/xapian")
file(MAKE_DIRECTORY "${PY_PKG_DIR}")
add_custom_command(TARGET xapian_python3 POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${PY3_SRC}/xapian__init__.py" "${PY_PKG_DIR}/__init__.py"
  COMMENT "Staging Python3 xapian package into ${PY_PKG_DIR}"
)

enable_testing()
add_test(
  NAME python3-smoke
  COMMAND ${Python3_EXECUTABLE} -c "import sys; sys.path.insert(0, r'${CMAKE_BINARY_DIR}/python3'); import xapian; print(xapian.version_string())"
)
set_tests_properties(python3-smoke PROPERTIES ENVIRONMENT "PYTHONPATH=${CMAKE_BINARY_DIR}/python3")

install(TARGETS xapian_python3 DESTINATION "${Python3_SITEARCH}/xapian")
install(FILES "${PY3_SRC}/xapian__init__.py" DESTINATION "${Python3_SITEARCH}/xapian" RENAME __init__.py)
