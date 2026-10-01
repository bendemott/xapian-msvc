# CMake skeleton (not a complete build)

These files show the shape of an MSVC-native, MSYS-free build:

- `CMakeLists.txt` — project options, probes, library target wiring
- `config.h.cmake` — replaces autoconf `config.h`, including MSVC large-file hacks
- `version.h.cmake` — replaces preprocessor-generated `xapian/version.h`, with optional `__declspec` exports

They intentionally do **not** compile until you import xapian-core and fill `XAPIAN_LIB_SOURCES` from Automake’s `lib_src` lists.

Related: [../../docs/cmake-port-checklist.md](../../docs/cmake-port-checklist.md)
