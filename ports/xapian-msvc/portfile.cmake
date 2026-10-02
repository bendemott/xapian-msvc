# SPDX-License-Identifier: GPL-2.0-or-later
#
# Overlay port for https://github.com/bendemott/xapian-msvc
# Name is xapian-msvc so it does not collide with the autotools-based
# microsoft/vcpkg port "xapian" (1.4.x).

# Prefer the enclosing source tree when this port is used via
#   vcpkg install --overlay-ports=ports xapian-msvc
# from a checkout of bendemott/xapian-msvc. Fall back to a tagged GitHub
# archive once releases exist.
set(_xapian_msvc_root "${CMAKE_CURRENT_LIST_DIR}/../..")
if(EXISTS "${_xapian_msvc_root}/CMakeLists.txt"
   AND EXISTS "${_xapian_msvc_root}/scripts/import-xapian.py")
  set(SOURCE_PATH "${_xapian_msvc_root}")
  message(STATUS "xapian-msvc: building overlay tree ${SOURCE_PATH}")
else()
  vcpkg_from_github(
      OUT_SOURCE_PATH SOURCE_PATH
      REPO bendemott/xapian-msvc
      REF "v${VERSION}"
      SHA512 0
      HEAD_REF main
  )
endif()

set(XAPIAN_FEATURES
    -DXAPIAN_VERSION=${VERSION}
    -DXAPIAN_BUILD_SMOKE_TEST=OFF
    -DXAPIAN_BUILD_TESTS=OFF
    -DXAPIAN_BUILD_PYTHON3=OFF
    -DBUILD_SHARED_LIBS=OFF
)

if("tools" IN_LIST FEATURES)
    list(APPEND XAPIAN_FEATURES -DXAPIAN_BUILD_TOOLS=ON)
else()
    list(APPEND XAPIAN_FEATURES -DXAPIAN_BUILD_TOOLS=OFF)
endif()

if("letor" IN_LIST FEATURES)
    list(APPEND XAPIAN_FEATURES -DXAPIAN_BUILD_LETOR=ON)
else()
    list(APPEND XAPIAN_FEATURES -DXAPIAN_BUILD_LETOR=OFF)
endif()

if("omega" IN_LIST FEATURES)
    list(APPEND XAPIAN_FEATURES -DXAPIAN_BUILD_OMEGA=ON)
else()
    list(APPEND XAPIAN_FEATURES -DXAPIAN_BUILD_OMEGA=OFF)
endif()

# Import upstream sources into third_party/ before configure.
vcpkg_find_acquire_program(PYTHON3)
vcpkg_execute_required_process(
    COMMAND "${PYTHON3}" "${SOURCE_PATH}/scripts/import-xapian.py" --version "${VERSION}"
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME import-xapian
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${XAPIAN_FEATURES}
)

vcpkg_cmake_install()
vcpkg_cmake_config_fix(
    PACKAGE_NAME Xapian
    CONFIG_PATH lib/cmake/Xapian
    DO_NOT_DELETE_PARENT_CONFIG_PATH
)

if("tools" IN_LIST FEATURES)
    vcpkg_copy_tools(
        TOOL_NAMES
            xapian-check
            xapian-compact
            xapian-delve
            xapian-quest
            xapian-progsrv
            xapian-replicate
            xapian-replicate-server
            xapian-tcpsrv
        AUTO_CLEAN
    )
endif()

if("omega" IN_LIST FEATURES)
    vcpkg_copy_tools(
        TOOL_NAMES omega scriptindex omindex omindex-list
        AUTO_CLEAN
    )
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/third_party/xapian-core/COPYING")
