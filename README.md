# Xapian Core → MSVC / CMake portability investigation

Investigation of what it takes to run **xapian-core** on Windows with the **MSVC toolchain** without depending on MinGW/MSYS2 as a build host, while remaining cross-platform (Windows + Linux + macOS).

## Short answer

**You do not need to rewrite Xapian’s C++ for MSVC.** Upstream xapian-core already compiles and passes its testsuite under MSVC 2015–2022 (AppVeyor + INSTALL docs). The real dependency is the **build host**: GNU autotools, libtool, and GNU make, usually via **MSYS2**. MinGW-as-compiler is an *alternative* Windows path, not a requirement for MSVC.

What a fork (or upstream contribution) must deliver is a **native CMake (or MSBuild) build** that:

1. Generates `config.h` / `xapian/version.h` without `./configure`
2. Builds the ~200 library translation units with `cl.exe` / Ninja / Visual Studio generators
3. Links **zlib** (and optionally ICU) via CMake `find_package`
4. Works the same way on Linux/macOS (so the tree is not Windows-only)

Source-level Windows shims already exist (`safe*.h`, `posixy_wrapper`, `msvc_dirent`, Win32 locking, `CreateProcess` remote spawn, Win32 UUID API).

## What’s in this repo

| Path | Purpose |
|------|---------|
| [docs/investigation.md](docs/investigation.md) | Full findings, blockers, work packages, fork strategy |
| [docs/cmake-port-checklist.md](docs/cmake-port-checklist.md) | Concrete implementation checklist |
| [cmake/skeleton/](cmake/skeleton/) | Illustrative CMake + `config.h.cmake` starting point (not a full port) |
| [scripts/import-xapian-core.sh](scripts/import-xapian-core.sh) | Fetch a release tarball (recommended base; includes generated sources) |

## Recommended starting point

Use the **release tarball** of xapian-core (e.g. **2.1.0** or the **1.4.x** LTS line), not a raw git checkout. Releases already contain Lemon/Snowball/exception/unicode generated sources and `configure`. Git master needs `bootstrap` + Perl/Snowball/Lemon regenerators.

```bash
./scripts/import-xapian-core.sh 2.1.0
```

## Upstream vs fork

| Option | When it makes sense |
|--------|---------------------|
| **Contribute CMake upstream** | Prefer this if the goal is longevity; Olly has historically wanted MSVC to work via the standard build, and rejected ad-hoc VS projects, but a clean CMake dual-build is a different ask |
| **Soft fork of xapian-core only** | Faster iteration; keep syncing from upstream; drop omega/bindings until later |
| **Hard fork of entire monorepo** | Only if you need divergent API/ABI or packaging policy |

This environment could not create a GitHub fork (`gh` is not authenticated). To fork yourself: `https://github.com/xapian/xapian` → Fork, then clone only `xapian-core` history or import a release tarball as above.

## License

Xapian is **GPL-2.0-or-later**. A fork remains GPL. Linking proprietary code has the usual GPL consequences; that is orthogonal to MSVC support but often the real adoption blocker on Windows.

## Status of this investigation

Based on upstream git `master` (commit around `338c080`, “Fix MSVC warnings…”) and the **xapian-core 2.1.0** release tarball, plus AppVeyor/vcpkg packaging practice. No full CMake port was implemented here—only the analysis and a skeleton to start from.
