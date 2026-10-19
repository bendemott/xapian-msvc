# SPDX-License-Identifier: GPL-2.0-or-later
#
# Read the libxapian source list (lib_src) from upstream's automake files so the
# build follows whichever xapian-core release sits in XAPIAN_SOURCE_ROOT.
# A hard-coded list breaks across releases: 2.0.0 has api/valuerangeproc.cc
# and languages/utilities.cc where 2.1.0 has api/rangeproc.cc and
# languages/snowball_runtime.cc, and the set of stemmers changes as well.
#
# Only the automake syntax xapian-core uses around lib_src is understood:
# `include FILE`, `VAR =` / `VAR +=` with backslash continuations, `$(VAR)` and
# `$(VAR:.from=.to)` references, and nested `if [!]COND` / `else` / `endif`.
# Recipe lines (leading tab) are ignored.

# Return the text of an automake file with `include` lines replaced by the
# included file's text (recursively), CRLF normalised and continuations joined.
function(_xapian_am_read_flat root relpath out_var)
  set(_path "${root}/${relpath}")
  if(NOT EXISTS "${_path}")
    message(FATAL_ERROR "xapian-core automake file not found: ${_path}")
  endif()
  file(READ "${_path}" _text)
  string(REPLACE "\r\n" "\n" _text "${_text}")
  string(REGEX REPLACE "\\\\\n" " " _text "${_text}")

  # Brackets would confuse CMake's list splitting; no lib_src entry uses them.
  string(REPLACE "[" "_LBRACKET_" _text "${_text}")
  string(REPLACE "]" "_RBRACKET_" _text "${_text}")
  string(REPLACE ";" "_SEMICOLON_" _text "${_text}")
  string(REPLACE "\n" ";" _lines "${_text}")
  set(_flat "")
  foreach(_line IN LISTS _lines)
    if(_line MATCHES "^include[ \t]+([^ \t]+)[ \t]*$")
      # Some includes (docsource.mk) are generated and only exist in release
      # tarballs; none of those contribute to lib_src.
      if(EXISTS "${root}/${CMAKE_MATCH_1}")
        _xapian_am_read_flat("${root}" "${CMAKE_MATCH_1}" _inc)
        string(APPEND _flat "${_inc}")
      endif()
    else()
      string(APPEND _flat "${_line}\n")
    endif()
  endforeach()
  set(${out_var} "${_flat}" PARENT_SCOPE)
endfunction()

# Expand $(VAR) and $(VAR:.from=.to) using the caller's _am_var_<VAR>
# variables (a macro, so it sees them directly).
macro(_xapian_am_expand text out_var)
  set(_xe_result "${text}")
  foreach(_xe_pass RANGE 20)
    if(NOT _xe_result MATCHES "\\$\\(([A-Za-z0-9_]+)(:([^=)]*)=([^)]*))?\\)")
      break()
    endif()
    set(_xe_ref "${CMAKE_MATCH_0}")
    set(_xe_has_subst "${CMAKE_MATCH_2}")
    set(_xe_from "${CMAKE_MATCH_3}")
    set(_xe_to "${CMAKE_MATCH_4}")
    set(_xe_value "${_am_var_${CMAKE_MATCH_1}}")
    if(_xe_has_subst)
      string(REGEX REPLACE "[ \t]+" ";" _xe_words "${_xe_value}")
      string(REGEX REPLACE "([][+.*?^$()|\\\\])" "\\\\\\1" _xe_from_re "${_xe_from}")
      set(_xe_out)
      foreach(_xe_w IN LISTS _xe_words)
        if(NOT _xe_w STREQUAL "")
          string(REGEX REPLACE "${_xe_from_re}$" "${_xe_to}" _xe_w "${_xe_w}")
          list(APPEND _xe_out "${_xe_w}")
        endif()
      endforeach()
      list(JOIN _xe_out " " _xe_value)
    endif()
    string(REPLACE "${_xe_ref}" "${_xe_value}" _xe_result "${_xe_result}")
  endforeach()
  set(${out_var} "${_xe_result}")
endmacro()

# xapian_core_sources_from_automake(<root> <out_var>)
#
# Sets <out_var> to lib_src as paths relative to <root>, honouring the
# XAPIAN_ENABLE_BACKEND_{GLASS,HONEY,INMEMORY,REMOTE} options.
function(xapian_core_sources_from_automake root out_var)
  foreach(_backend GLASS HONEY INMEMORY REMOTE)
    if(XAPIAN_ENABLE_BACKEND_${_backend})
      set(_am_cond_BUILD_BACKEND_${_backend} 1)
    endif()
  endforeach()
  # Building from a release tarball: generated sources and docs are present,
  # and this is neither a maintainer-mode nor a VPATH build.
  set(_am_cond_MAINTAINER_NO_DOCS 1)

  _xapian_am_read_flat("${root}" "Makefile.am" _text)
  string(REPLACE "\n" ";" _lines "${_text}")

  set(_stack)
  foreach(_line IN LISTS _lines)
    if(_line MATCHES "^\t")
      continue()
    endif()
    string(REGEX REPLACE "#.*$" "" _line "${_line}")
    string(STRIP "${_line}" _line)
    if(_line STREQUAL "")
      continue()
    endif()

    if(_line MATCHES "^if[ \t]+(!?)([A-Za-z0-9_]+)$")
      set(_neg "${CMAKE_MATCH_1}")
      if(_am_cond_${CMAKE_MATCH_2})
        set(_v 1)
      else()
        set(_v 0)
      endif()
      if(_neg)
        math(EXPR _v "1 - ${_v}")
      endif()
      list(APPEND _stack ${_v})
      continue()
    elseif(_line STREQUAL "else")
      list(POP_BACK _stack _v)
      math(EXPR _v "1 - ${_v}")
      list(APPEND _stack ${_v})
      continue()
    elseif(_line STREQUAL "endif")
      list(POP_BACK _stack)
      continue()
    endif()

    if("0" IN_LIST _stack)
      continue()
    endif()

    # Variable assignment (not a rule: rules have a ':' before any '=').
    if(_line MATCHES "^([A-Za-z0-9_]+)[ \t]*(\\+?=)(.*)$")
      set(_name "${CMAKE_MATCH_1}")
      set(_op "${CMAKE_MATCH_2}")
      string(STRIP "${CMAKE_MATCH_3}" _rhs)
      if(_op STREQUAL "=")
        set(_am_var_${_name} "${_rhs}")
      else()
        set(_am_var_${_name} "${_am_var_${_name}} ${_rhs}")
      endif()
    endif()
  endforeach()

  if(_stack)
    message(FATAL_ERROR "Unbalanced if/endif while parsing ${root}/Makefile.am")
  endif()

  _xapian_am_expand("${_am_var_lib_src}" _src_text)
  string(REGEX REPLACE "[ \t]+" ";" _words "${_src_text}")
  set(_out)
  foreach(_w IN LISTS _words)
    if(_w MATCHES "\\.(cc|c|cpp)$")
      list(APPEND _out "${_w}")
    endif()
  endforeach()
  list(REMOVE_DUPLICATES _out)
  if(NOT _out)
    message(FATAL_ERROR "No lib_src entries found in ${root}/Makefile.am")
  endif()
  set(${out_var} "${_out}" PARENT_SCOPE)
endfunction()
