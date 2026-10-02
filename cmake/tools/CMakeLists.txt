# CLI tools from xapian-core (bin/). Expects XAPIAN_SOURCE_ROOT and Xapian::xapian.

add_library(xapian_getopt STATIC "${XAPIAN_SOURCE_ROOT}/common/getopt.cc")
target_include_directories(xapian_getopt PUBLIC
  "${XAPIAN_SOURCE_ROOT}/common"
  "${CMAKE_BINARY_DIR}"
)
# config.h (MSVC) includes zlib.h before redefining off_t.
if(TARGET zlibstatic)
  target_link_libraries(xapian_getopt PUBLIC zlibstatic)
elseif(TARGET ZLIB::ZLIB)
  target_link_libraries(xapian_getopt PUBLIC ZLIB::ZLIB)
elseif(DEFINED XAPIAN_ZLIB_TARGET)
  target_link_libraries(xapian_getopt PUBLIC ${XAPIAN_ZLIB_TARGET})
endif()
target_compile_definitions(xapian_getopt PRIVATE HAVE_CONFIG_H)

function(xapian_add_tool name)
  cmake_parse_arguments(T "" "" "SOURCES;EXTRA_LIBS" ${ARGN})
  if(NOT T_SOURCES)
    set(T_SOURCES "${XAPIAN_SOURCE_ROOT}/bin/${name}.cc")
  endif()
  add_executable(${name} ${T_SOURCES})
  target_include_directories(${name} PRIVATE
    "${CMAKE_BINARY_DIR}"
    "${XAPIAN_SOURCE_ROOT}"
    "${XAPIAN_SOURCE_ROOT}/common"
    "${XAPIAN_SOURCE_ROOT}/include"
    "${CMAKE_BINARY_DIR}/include"
  )
  target_compile_definitions(${name} PRIVATE HAVE_CONFIG_H)
  target_link_libraries(${name} PRIVATE Xapian::xapian xapian_getopt ${T_EXTRA_LIBS})
  if(WIN32)
    target_link_libraries(${name} PRIVATE ws2_32 rpcrt4)
  endif()
  install(TARGETS ${name} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
endfunction()

xapian_add_tool(xapian-delve)
xapian_add_tool(xapian-quest)
xapian_add_tool(xapian-check)
xapian_add_tool(xapian-compact)

if(XAPIAN_ENABLE_BACKEND_REMOTE)
  xapian_add_tool(xapian-progsrv)
  xapian_add_tool(xapian-replicate)
  xapian_add_tool(xapian-replicate-server)
  xapian_add_tool(xapian-tcpsrv SOURCES
    "${XAPIAN_SOURCE_ROOT}/bin/xapian-tcpsrv.cc"
    "${XAPIAN_SOURCE_ROOT}/bin/remotetcpserver.cc")
endif()

enable_testing()
add_test(NAME tool-delve-help COMMAND xapian-delve --help)
set_tests_properties(tool-delve-help PROPERTIES PASS_REGULAR_EXPRESSION "delve|Usage|usage")
