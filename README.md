# Xapian — CMake build (MSVC-friendly, cross-platform)

CMake port of **Xapian 2.1.0** (core, omega, Python 3 bindings) that builds
without MSYS2/autotools/MinGW. Verified on MSVC (Ninja+cl) and designed for
Linux/macOS as well.

## Quick start

```bash
# Linux / macOS
./build.sh import              # optional: third_party/{xapian-core,omega,bindings}
./build.sh build test
./build.sh build --python3 test
```

```powershell
# Windows (PowerShell) — loads MSVC itself; no Developer Prompt required
.\build.ps1 import
.\build.ps1 build test
.\build.ps1 build --python3 test
```

If `third_party/` trees are missing, CMake downloads the matching 2.1.0 tarballs
automatically for each enabled module.

### Manual cmake

```bash
python scripts/import-xapian.py   # optional; or: core omega bindings
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
ctest --test-dir build --output-on-failure

# Python 3 bindings (needs Python headers)
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DXAPIAN_BUILD_PYTHON3=ON
```

zlib / PCRE2 are found via `find_package` or fetched automatically if missing.

## Modules

| Module | CMake option | Default | Notes |
|--------|--------------|---------|-------|
| **xapian-core** library | (always) | — | glass/honey/inmemory/remote backends |
| Core CLI tools | `XAPIAN_BUILD_TOOLS` | ON | delve, compact, check, replicate, … |
| **xapian-omega** | `XAPIAN_BUILD_OMEGA` | ON | omindex, scriptindex, omega CGI; PCRE2 fetched if needed; libmagic stub on MSVC |
| **xapian-letor** | `XAPIAN_BUILD_LETOR` | ON | Learning-to-Rank library (from GitHub monorepo tag; no standalone tarball) |
| **Python 3** bindings | `XAPIAN_BUILD_PYTHON3` | OFF | pre-generated SWIG wrap; stage into `build/*/python3/xapian/` |

Smoke tests also cover dense-vector nearest-neighbour ranking via a cosine
`PostingSource` (Xapian has no built-in ANN index). Other binding languages in
the upstream tarball (Perl, Ruby, Java, …) are not wired yet — Python is first.

## What this repo provides

| Path | Role |
|------|------|
| `build.ps1` / `build.sh` | Build + smoke-test helpers (Windows / Unix) |
| `scripts/import-xapian.py` | Fetch official release tarballs into `third_party/` |
| `CMakeLists.txt` | Library + optional modules |
| `cmake/tools/` | Core CLI tools |
| `cmake/omega/` | Omega programs + MSVC config / magic stub |
| `cmake/letor/` | Learning-to-Rank library |
| `cmake/bindings-python3/` | `_xapian` extension module |
| `cmake/config.h.cmake` | Replaces autoconf `config.h` (MSVC large-file block) |
| `examples/smoke_test.cpp` | Index + search smoke test |
| `examples/vector_search_smoke.cpp` | Cosine vector nearest-neighbour smoke test |
| `examples/letor_smoke.cpp` | FeatureList / LTR smoke test |

## Options

| CMake option | Default | Meaning |
|--------------|---------|---------|
| `XAPIAN_ENABLE_BACKEND_GLASS` | ON | Glass disk backend |
| `XAPIAN_ENABLE_BACKEND_HONEY` | ON | Honey disk backend |
| `XAPIAN_ENABLE_BACKEND_INMEMORY` | ON | Inmemory backend |
| `XAPIAN_ENABLE_BACKEND_REMOTE` | ON | Remote / replication |
| `XAPIAN_USE_ICU` | OFF | ICU word-breaking |
| `BUILD_SHARED_LIBS` | OFF | Build DLL/so |
| `XAPIAN_BUILD_SMOKE_TEST` | ON | Library smoke executable |
| `XAPIAN_BUILD_TOOLS` | ON | Core CLI tools |
| `XAPIAN_BUILD_OMEGA` | ON | Omega programs |
| `XAPIAN_BUILD_LETOR` | ON | Learning-to-Rank library |
| `XAPIAN_BUILD_PYTHON3` | OFF | Python 3 bindings |

## Status

- **MSVC:** libxapian, core tools, omega, letor, vector-search smoke, and optional Python 3 bindings build; ctest smokes pass.
- **Omega on Windows:** MIME sniffing uses an extension-based stub when libmagic is absent; optional external format filters are not required for the core programs.
- **Easy upstream suite:** `XAPIAN_BUILD_TESTS=ON` runs none/inmemory/glass/honey + stem/internal/unit (a few MSVC-only SKIPs).
- **Not yet:** full remote/replication/omega testsuite under CTest; non-Python bindings; maintainer Snowball regeneration.

## Prebuilt Windows libraries

GitHub Actions builds an **MSVC x64 static** package whenever:

- you push a `v*.*.*` tag, or
- you run **Actions → release → Run workflow** with a version, or
- **watch-upstream** sees a new `vX.Y.Z` tag on [xapian/xapian](https://github.com/xapian/xapian) (and the oligarchy tarball exists)

Download `xapian-msvc-<ver>-windows-x64.zip` from [Releases](https://github.com/bendemott/xapian-msvc/releases), unzip, then:

```cmake
list(APPEND CMAKE_PREFIX_PATH "C:/libs/xapian-msvc-2.1.0-windows-x64")
find_package(Xapian 2.1.0 REQUIRED)
target_link_libraries(myapp PRIVATE Xapian::xapian)   # and/or Xapian::letor
```

You still need zlib when building from source / vcpkg; the **release zip
bundles** `zlibstatic.lib` + headers so a single `CMAKE_PREFIX_PATH` is enough.

To publish the current tree as 2.1.0 once:

```text
Actions → release → Run workflow → version=2.1.0
```

## vcpkg

This repo ships an overlay port named **`xapian-msvc`** (avoids clashing with the official autotools `xapian` 1.4.x port).

```powershell
# from a checkout of this repo
vcpkg install xapian-msvc --overlay-ports="$PWD/ports"
```

```cmake
find_package(Xapian CONFIG REQUIRED)
target_link_libraries(myapp PRIVATE Xapian::xapian Xapian::letor)
```

Features: `letor` (default), `tools` (default), `omega` (optional, pulls `pcre2`).

## Using the Python module

After `build --python3`:

```powershell
$env:PYTHONPATH = "$PWD\build\release\python3"
python -c "import xapian; print(xapian.version_string())"
```

## License

Xapian is **GPL-2.0-or-later** (see `third_party/*/COPYING` after import). This
CMake glue is provided under the same license terms when distributed with Xapian.
