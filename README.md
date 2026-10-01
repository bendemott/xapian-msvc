# Xapian Core — CMake build (MSVC-friendly, cross-platform)

CMake port of **xapian-core 2.1.0** that builds without MSYS2/autotools/MinGW.
Verified on Linux; designed for MSVC (`Visual Studio 17 2022` / Ninja+cl) as well.

## Quick start

```bash
# 1) Fetch upstream release sources (includes generated Snowball/Lemon files)
./scripts/import-xapian-core.sh 2.1.0

# 2) Configure & build (Ninja or Make)
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build -j

# 3) Smoke test
./build/xapian-cmake-smoke
# or: ctest --test-dir build --output-on-failure
```

### Windows (MSVC, no MinGW/MSYS2)

From a **Developer Command Prompt for VS** (or any shell where `cl` works).
If `third_party/xapian-core` is missing, CMake downloads the 2.1.0 release automatically:

```bat
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
ctest --test-dir build -C Release --output-on-failure
```

Or with Ninja after `vcvars64.bat`:

```bat
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

zlib is found via `find_package(ZLIB)` or fetched automatically if missing.

## What this repo provides

| Path | Role |
|------|------|
| `CMakeLists.txt` | Real library build + smoke test |
| `cmake/config.h.cmake` | Replaces autoconf `config.h` (includes MSVC large-file block) |
| `cmake/version.h.in` | Public `xapian/version.h` |
| `cmake/visibility.h` | GCC visibility **and** MSVC `__declspec` for DLLs |
| `cmake/XapianFeatureChecks.cmake` | Feature probes |
| `cmake/xapian_core_sources.cmake` | 239 translation units from upstream `lib_src` |
| `examples/smoke_test.cpp` | Index + search smoke test |
| `docs/investigation.md` | Background on why CMake vs autotools/MSYS |

## Options

| CMake option | Default | Meaning |
|--------------|---------|---------|
| `XAPIAN_ENABLE_BACKEND_GLASS` | ON | Glass disk backend |
| `XAPIAN_ENABLE_BACKEND_HONEY` | ON | Honey disk backend |
| `XAPIAN_ENABLE_BACKEND_INMEMORY` | ON | Inmemory backend |
| `XAPIAN_ENABLE_BACKEND_REMOTE` | ON | Remote / replication |
| `XAPIAN_USE_ICU` | OFF | ICU word-breaking |
| `BUILD_SHARED_LIBS` | OFF | Build DLL/so (uses `visibility.h` dllexport on Windows) |
| `XAPIAN_BUILD_SMOKE_TEST` | ON | Build/run smoke executable |

## Status

- **Linux:** static `libxapian.a` builds; smoke test passes (glass DB index/search).
- **MSVC:** build files and MSVC `config.h` bottom-matter are in place; CI workflow builds on `windows-2022`.
- **Not yet:** full upstream testsuite under CTest, omega/bindings, maintainer Snowball regeneration.

## License

xapian-core is **GPL-2.0-or-later** (see `third_party/xapian-core/COPYING` after import). This CMake glue is provided under the same license terms when distributed with Xapian.
