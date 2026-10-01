# CMake port checklist (xapian-core)

Use a **release tarball** as the base (generated sources present).

## Milestone A — configures and compiles static lib

- [ ] Import `xapian-core-VERSION` via `scripts/import-xapian-core.sh`
- [ ] Root `CMakeLists.txt` with `cmake_minimum_required`, `project(xapian VERSION … LANGUAGES CXX)`, `CMAKE_CXX_STANDARD 17`
- [ ] Options: `BUILD_SHARED_LIBS`, `XAPIAN_ENABLE_BACKEND_GLASS`, `HONEY`, `INMEMORY`, `REMOTE`, `USE_ICU`, `BUILD_TOOLS`, `BUILD_TESTS`
- [ ] `find_package(ZLIB REQUIRED)`
- [ ] Generate `config.h` from `cmake/config.h.cmake` (include MSVC `AH_BOTTOM` large-file / warning block)
- [ ] Generate `include/xapian/version.h`
- [ ] Collect sources from Automake `lib_src` lists (script-assisted once, then maintain)
- [ ] On Windows add `common/msvc_dirent.cc`; define `__WIN32__` consistency via config
- [ ] `target_include_directories` for `common/`, `include/`, build dir
- [ ] `target_compile_definitions PRIVATE XAPIAN_LIB_BUILD PACKAGE=…)`
- [ ] Link `ZLIB::ZLIB`; on Windows link `ws2_32`, `rpcrt4` (UUID) as needed
- [ ] Smoke executable: open inmemory or glass DB, index one doc, search

## Milestone B — shared library + tools

- [ ] Map `XAPIAN_VISIBILITY_*` to `__declspec(dllexport/dllimport)` on Windows
- [ ] Export set / `generate_export_header` alternative if preferred
- [ ] Build `bin/xapian-*` tools that don’t need special generator bits
- [ ] Install rules + `xapian-config.cmake` (upstream already has cmake package templates under `cmake/`)

## Milestone C — tests & CI

- [ ] Port or wrap a subset of `tests/api_*.cc` under CTest
- [ ] Skip / isolate remote and replication tests on Windows initially
- [ ] CI matrix: windows-2022 (MSVC), ubuntu-latest (clang/gcc), macos-latest
- [ ] Match `/MD` runtime; test Debug and Release on MSVC

## Milestone D — sync & polish

- [ ] Document dual-build (autotools still works) or drop autotools in the fork
- [ ] Script to replay upstream release diffs
- [ ] Optional ICU
- [ ] Consider proposing CMake upstream instead of maintaining a hard fork

## Explicit non-goals for first slice

- Omega / bindings / letor
- Full parity of every historic `configure` probe
- Maintainer regeneration of Snowball/Lemon in CI
- Perfect remote multiprocess semantics on Windows
