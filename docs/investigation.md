# Investigating an MSVC-native, MinGW-free Xapian Core

## 1. Clarify the problem

People often say “Xapian needs MinGW on Windows.” That mixes three different things:

| Layer | What people mean | Current upstream reality |
|-------|------------------|---------------------------|
| **Compiler** | Must use MinGW `g++` | **False.** MSVC (`cl`) is supported since ~1.4.6 |
| **Build tools** | Need a Unix-like shell (`bash`, `make`, `autoconf`) | **True.** Documented path is MSYS2 + `./configure` + GNU make |
| **Runtime ABI** | App must be MinGW-built to link Xapian | **False for MSVC builds.** An MSVC-built `xapian` links into MSVC apps. A MinGW-built DLL does *not* mix cleanly with MSVC |

So the fork goal is not “port the C++ to MSVC.” It is **replace autotools/libtool as the only supported Windows driver** with something Visual Studio / `cmake --build` can run without MSYS2.

Cross-platform still means: same sources build on Linux and macOS (CMake is the natural common denominator).

## 2. What already works on MSVC

Upstream has invested in this for years:

- **INSTALL** documents MSVC ≥ 2017 (C++17 for 2.x; 1.4.x is C++11) with:
  ```text
  ./configure CC=cl CXX="$PWD/compile cl" AR=lib LD=link NM=dumpbin
  make
  ```
- **AppVeyor** (`.appveyor.yml`) builds xapian-core with VS 2017/2019, x86 and x64, runs `make check`.
- Recent commits still touch MSVC (e.g. enable `/W3`, fix warnings).
- **vcpkg** ships a `xapian` port that builds the release tarball with autotools wrappers on `x64-windows` (MSVC).
- Ticket history (#169, #806) confirms core + tests on MSVC; omega/bindings still weak.

### Windows-aware source already in tree

Roughly **50+ files** branch on `__WIN32__` / `_MSC_VER`. Important pieces:

| Area | Mechanism |
|------|-----------|
| Headers | `safeunistd.h`, `safewindows.h`, `safewinsock2.h`, `safesysstat.h`, `safedirent.h`, … |
| POSIX I/O semantics | `posixy_wrapper` (`open`/`rename`/`unlink` that allow deleting open files) |
| `dirent` | `msvc_dirent.cc` |
| DB locking | `flint_lock` uses `CreateFileA` on Windows (note: blocking lock via `LockFileEx` still marked FIXME) |
| Remote “prog” client | `CreateProcessA` instead of `fork`/`exec` |
| TCP remote server | Separate non-`fork` path on Windows |
| UUID | `USE_WIN32_UUID_API` |
| Large files | `stat`/`fstat`/`lseek`/`off_t` remapped to 64-bit MSVC APIs in `config.h` bottom matter |
| CRT noise | `_CRT_SECURE_NO_WARNINGS`, `MSVCIgnoreInvalidParameter`, etc. |

**Verdict:** Source portability for MSVC is largely a solved problem. Do not start by rewriting backends.

## 3. What “remove MinGW/MSYS dependency” actually costs

### 3.1 Replace configure (largest piece)

`configure.ac` is ~1,850 lines. Generated `config.h.in` has ~140 `#undef` knobs. Many are Unix-only (`HAVE_FORK`, `HAVE_PREAD`, `HAVE_SOCKETPAIR`, …) and simply stay undefined on Windows. A CMake port needs:

1. **`config.h.cmake`** (or hand-maintained `config.h` per platform) covering the defines the library actually reads.
2. **Feature checks** via `check_cxx_source_compiles` / `check_symbol_exists` for the ones that matter on all platforms (zlib, `ssize_t`, byte-swap intrinsics, `std::from_chars`, ICU optional, …).
3. **MSVC-specific bottom of `config.h`** — currently injected by `AH_BOTTOM` in autoconf (large-file macros, `__WIN32__` alias from `_WIN32`, pragma disables). This must be copied carefully into the CMake template.

Starting from a **release tarball** avoids regenerating Snowball/Lemon/exceptions/unicode.

### 3.2 Replace `version.h` generation

`include/xapian/version_h.cc` is a template run through the C++ preprocessor, then massaged into `xapian/version.h`. It encodes:

- Version numbers
- Backend enable macros (`XAPIAN_HAS_GLASS_BACKEND`, …)
- Integer base types
- MSVC `_DEBUG` mismatch guards (important for CRT)

CMake can:

- Run `cl /E` / `${CMAKE_CXX_COMPILER} -E` + a small Python/CMake script (closest to upstream), or
- Emit `version.h` directly from `configure_file()` (simpler, slightly diverges from upstream’s process).

### 3.3 Compile the library without libtool

~200 `.cc` files feed `libxapian`. Automake lists them across many `Makefile.mk` fragments with conditionals:

- remote / replication sources only if remote enabled
- `msvc_dirent.cc` only on Windows
- compression via zlib always
- optional ICU word-breaking

CMake should mirror those `OPTION()`s. Prefer **static library first** on MSVC.

### 3.4 Shared library / DLL exports (if you need a DLL)

Public API uses `XAPIAN_VISIBILITY_DEFAULT`, which expands to GCC `visibility("default")` when enabled, otherwise **empty**.

On MSVC, empty means **no `__declspec(dllexport)`**. Upstream relies on libtool’s Windows shared-library machinery. A CMake DLL build should redefine:

```cpp
#if defined(_WIN32) && defined(XAPIAN_BUILD_DLL)
#  ifdef XAPIAN_LIB_BUILD
#    define XAPIAN_VISIBILITY_DEFAULT __declspec(dllexport)
#  else
#    define XAPIAN_VISIBILITY_DEFAULT __declspec(dllimport)
#  endif
#endif
```

(plus the same for `XAPIAN_VISIBILITY_INTERNAL` as empty). This is a small, high-value fork delta if DLLs matter.

### 3.5 Dependencies

| Dep | Required? | Notes |
|-----|-----------|-------|
| **zlib** | Yes | Use CMake `find_package(ZLIB)` or FetchContent; MSVC must match `/MD` vs `/MT` |
| **ICU** | Optional | Word breaking for some scripts; skip initially |
| **libuuid** | No on Windows | Win32 UUID API |
| **Perl / Snowball / Lemon** | Only for git maintainer builds | Avoid by using a release tarball |
| **pkg-config** | No if CMake finds zlib/ICU | |

### 3.6 Tools / tests / remote backend quirks

- CLI tools (`xapian-compact`, `xapian-delve`, …) are straightforward once the lib builds.
- Test harness has Windows branches but expects a Unix-ish runner environment today (`make check` under MSYS). Porting `make check` to CTest is a separate chunk.
- Remote TCP server and flint lock on Windows are functional but not as polished as Unix (`LockFileEx` FIXME; no `fork`-style isolation).

### 3.7 What you can ignore for “core compiles on MSVC via CMake”

- xapian-omega, xapian-bindings, xapian-letor
- Documentation toolchain (sphinx, doxygen, help2man)
- Emscripten bits
- Contributing a full replacement for every obscure `configure` probe on HP-UX/AIX/etc. — gate those behind `if(UNIX)`

## 4. Size of the codebase (xapian-core only)

| Metric | Approx. |
|--------|---------|
| Headers + sources | ~570 files |
| Lines | ~160k |
| Library `.cc` units | ~200 |
| Windows-conditioned files | ~50–60 |
| License | GPL-2.0-or-later |

This is a medium-large C++ library, but the MSVC-shaped work is concentrated in **build system + a few export macros**, not a ground-up rewrite.

## 5. Fork strategy

### 5.1 Soft fork of core only (recommended)

1. Import **xapian-core 2.1.0** (or 1.4.32 if you need the stable series) into your repo.
2. Keep upstream `configure` working initially (dual-build) so you can diff behavior.
3. Add CMake beside it; make CMake the supported Windows path.
4. Periodically merge upstream release diffs (they are manageable if you avoid rewriting source layout).

### 5.2 Full monorepo fork

Only if you also need omega/bindings under MSVC. Bindings imply SWIG + per-language Windows story — much larger than core.

### 5.3 Don’t fork if…

If MSYS2 + MSVC `cl` already satisfies “it runs on Windows,” use **vcpkg’s xapian port** or upstream AppVeyor instructions. Forking is justified when you need:

- Visual Studio solution / `cmake -G Ninja` with no MSYS
- Corporate build systems that forbid Unix shells on Windows agents
- First-class DLL exports / NuGet / cleaner MSVC packaging
- Divergent features

### 5.4 GitHub fork note

This agent session has no GitHub auth (`gh auth` logged out), so no fork was created under your account. Manual steps:

```bash
# on your machine
gh repo fork xapian/xapian --clone
cd xapian
# orphan or subtree just xapian-core, or start from release tarball
```

## 6. Work packages (technical scope, not calendar estimates)

Ordered for a useful first milestone: **static libxapian + one example on MSVC and Linux**.

1. **Import release tree** of xapian-core; pin version; document GPL.
2. **CMake project skeleton**: `project(xapian-core)`, C++17, `add_library(xapian ...)`.
3. **`config.h` for MSVC + Linux**: hard-code known Windows values first; add checks for Unix.
4. **`version.h` emission**.
5. **Source list + platform conditionals** (`msvc_dirent`, remote on/off).
6. **Zlib linkage**; smoke-test `WritableDatabase` open/add/commit/search.
7. **MSVC DLL export macros** (if shared needed).
8. **CLI tools**.
9. **CTest** subset of `tests/` (api tests first; skip remote/fork-heavy cases initially).
10. **CI**: GitHub Actions — `windows-2022` MSVC + `ubuntu` + `macos`.
11. **Optional**: ICU, packaging (vcpkg overlay, Conan), contribute CMake upstream.

Package (1)–(6) is the critical path. Most of it is build-system engineering; source changes should stay small.

## 7. Risks and footguns

| Risk | Mitigation |
|------|------------|
| Diverging from upstream forever | Dual-build early; minimize source edits; prefer CMake-only patches |
| Debug/Release CRT mismatch | Keep upstream `_DEBUG` checks in `version.h`; document `/MD` |
| Incomplete `config.h` | Build with a define-audit (fail on `#error` / missing HAVE_*) |
| Assuming MinGW headers | Never include MinGW-only paths; use MSVC CRT + Win32 |
| GPL + proprietary app | Legal/product decision; not solved by MSVC |
| Remote/replication on Windows | Enable after local glass/honey backends prove out |
| C++20 + Windows RPC `byte` clash | Fixed in newer trees; don’t force C++20 on 1.4.x core builds |

## 8. Conclusion

Forking xapian-core for “MSVC without MinGW” is **primarily a build-system project**, not a compiler-portability project. Upstream already proves the sources compile and test under MSVC when driven by autotools on MSYS2. The valuable fork (or contribution) is **CMake + proper MSVC DLL annotations + CI**, keeping the existing Windows shims and remaining cross-platform by building that same CMake on Linux/macOS.

See [cmake-port-checklist.md](cmake-port-checklist.md) for an implementation checklist and [../cmake/skeleton/](../cmake/skeleton/) for a starting outline.
