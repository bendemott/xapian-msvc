#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Ben DeMott
# xapian-msvc build helper for Linux and macOS. The Windows twin is build.ps1.
#
#   ./build.sh                    help
#   ./build.sh build test         commands chain and always run in a fixed order
#   ./build.sh test --help        help for one command
#
# Plain bash 3.2 (the macOS default): no associative arrays, no ${x,,}, and
# possibly-empty arrays expand as ${a[@]+"${a[@]}"} because of set -u.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
SELF="./build.sh"
XAPIAN_VERSION="2.1.0"

# Commands run in this order, whatever order they were typed in.
ORDER="doctor clean import build test"

# ---------------------------------------------------------------------------
# colors and messages

COLOR_MODE=auto
ARGS=()
for a in "$@"; do
    case "$a" in
        --no-color) COLOR_MODE=never; continue ;;
        --color) COLOR_MODE=always; continue ;;
    esac
    ARGS+=("$a")
done

use_color() {
    case "$COLOR_MODE" in always) return 0 ;; never) return 1 ;; esac
    [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ] && [ -t "$1" ]
}

if use_color 2; then
    E_B=$'\033[1;34m' E_G=$'\033[1;32m' E_Y=$'\033[1;33m' E_R=$'\033[1;31m' E_C=$'\033[1;36m' E_D=$'\033[2m' E_0=$'\033[0m'
else
    E_B='' E_G='' E_Y='' E_R='' E_C='' E_D='' E_0=''
fi
if use_color 1; then
    OUT_COLOR=1 O_H=$'\033[1m' O_C=$'\033[1;36m' O_O=$'\033[33m' O_G=$'\033[32m' O_D=$'\033[2m' O_0=$'\033[0m'
else
    OUT_COLOR=0 O_H='' O_C='' O_O='' O_G='' O_D='' O_0=''
fi

say()  { printf '%s==>%s %s\n' "$E_B" "$E_0" "$*" >&2; }
ok()   { printf '%s==>%s %s\n' "$E_G" "$E_0" "$*" >&2; }
warn() { printf '%swarning:%s %s\n' "$E_Y" "$E_0" "$*" >&2; }
die() {
    printf '%serror:%s %s\n' "$E_R" "$E_0" "$1" >&2
    shift
    local line
    for line in "$@"; do printf '%s\n' "$line" | sed 's/^/       /' >&2; done
    exit 1
}
usage_die() {
    local hint="$SELF help"
    [ -n "${2:-}" ] && hint="$SELF $2 --help"
    die "$1" "see: $hint"
}

# ---------------------------------------------------------------------------
# help text

HB=""
MARKUP_RE='^([^{]*)\{[a-z]:([^}]*)\}(.*)$'

strip_markup() {
    local s="$1" out=""
    while [[ $s =~ $MARKUP_RE ]]; do
        out="$out${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
        s="${BASH_REMATCH[3]}"
    done
    printf '%s' "$out$s"
}

h() { HB="$HB${1:-}"$'\n'; }

hrow() {
    local vis pad
    vis="$(strip_markup "$1")"
    pad=$((36 - ${#vis}))
    if [ "$pad" -lt 2 ]; then
        h "  $1"
        h "$(printf '%38s' '')$2"
    else
        h "  $1$(printf '%*s' "$pad" '')$2"
    fi
}

hflush() {
    if [ "$OUT_COLOR" = 1 ]; then
        printf '%s' "$HB" | sed -E \
            -e "s/\{h:([^}]*)\}/${O_H}\1${O_0}/g" \
            -e "s/\{c:([^}]*)\}/${O_C}\1${O_0}/g" \
            -e "s/\{o:([^}]*)\}/${O_O}\1${O_0}/g" \
            -e "s/\{g:([^}]*)\}/${O_G}\1${O_0}/g" \
            -e "s/\{d:([^}]*)\}/${O_D}\1${O_0}/g"
    else
        printf '%s' "$HB" | sed -E -e 's/\{[a-z]:([^}]*)\}/\1/g'
    fi
    HB=""
}

help_main() {
    h "{h:xapian-msvc build helper} {d:(build.sh: Linux and macOS, build.ps1: Windows)}"
    h
    h "{h:usage:} $SELF {c:<command>} [{o:options}] [{c:<command>} [{o:options}] ...]"
    h
    h "Commands can be combined. They always run in this order, whatever order"
    h "you type them in:"
    h
    h "    {c:doctor} > {c:clean} > {c:import} > {c:build} > {c:test}"
    h
    h "so {g:$SELF test build} builds, then tests. Options belong to the command"
    h "before them and can be written {o:--debug} or {o:debug}."
    h
    h "{h:commands:}"
    hrow "{c:help}" "this text; {c:<command> help} for one command"
    hrow "{c:doctor}" "show the tools the build uses"
    hrow "{c:clean}" "delete build/"
    hrow "{c:import} [{o:X.Y.Z}]" "download core+omega+bindings into third_party/ (default $XAPIAN_VERSION)"
    hrow "{c:build} [{o:--release}|{o:--debug}] [{o:--python3}]" "configure + build (default --release)"
    hrow "{c:test}" "smoke tests via ctest (builds first)"
    h
    h "{h:examples:}"
    hrow "{g:$SELF build test}" "configure, build, run smoke tests"
    hrow "{g:$SELF build --python3 test}" "also build Python 3 bindings"
    hrow "{g:$SELF clean build --debug test}" "fresh debug build, then test"
    hrow "{g:$SELF import build}" "import sources, then build"
    h
    h "{h:global options:}"
    hrow "{o:--no-color}, {o:--color}" "turn colored output off / on (NO_COLOR=1 also turns it off)"
    h
    h "{h:needs:} cmake 3.20+, a C++17 compiler, ninja (recommended), zlib headers,"
    h "and on Linux often uuid-dev. If third_party/ sources are missing, CMake"
    h "downloads $XAPIAN_VERSION automatically (or run {c:import} first)."
    h "Python 3 + headers needed only for {o:--python3}."
    hflush
}

help_cmd() {
    case "$1" in
        help) help_main; return ;;
        doctor)
            h "{h:usage:} $SELF {c:doctor}"
            h
            h "Lists the compilers and build tools the other commands use, and what's missing."
            ;;
        clean)
            h "{h:usage:} $SELF {c:clean}"
            h
            h "Deletes build/. Chain it to start fresh: {g:$SELF clean build}."
            ;;
        import)
            h "{h:usage:} $SELF {c:import} [{o:X.Y.Z}]"
            h
            h "Runs scripts/import-xapian.py to download official release tarballs for"
            h "xapian-core, xapian-omega, and xapian-bindings into third_party/."
            h "Default version: $XAPIAN_VERSION. Needs Python 3."
            ;;
        build)
            h "{h:usage:} $SELF {c:build} [{o:--release}|{o:--debug}] [{o:--python3}]"
            h
            h "Configures with CMake (Ninja) and builds libxapian, core CLI tools, omega,"
            h "and the smoke test into build/<type>/."
            h
            h "{h:options:}"
            hrow "{o:--release}" "optimized build (default)"
            hrow "{o:--debug}" "debug build"
            hrow "{o:--python3}" "also build Python 3 bindings"
            ;;
        test)
            h "{h:usage:} $SELF {c:test}"
            h
            h "Builds (release, or the type {c:build} picked on the same command line), then"
            h "runs ctest smoke tests (library, tools, omega; Python if {o:--python3})."
            ;;
        *) usage_die "no help for '$1'" ;;
    esac
    hflush
}

# ---------------------------------------------------------------------------
# helpers

os_name() {
    case "$(uname -s)" in
        Linux) echo linux ;;
        Darwin) echo macos ;;
        *) die "unsupported OS $(uname -s); use build.ps1 on Windows" ;;
    esac
}

ncpu() {
    if command -v nproc >/dev/null 2>&1; then nproc
    else sysctl -n hw.ncpu 2>/dev/null || echo 4
    fi
}

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found. $2"; }

BUILT_release=0
BUILT_debug=0

ensure_built() {
    local preset="$1" dir cmake_type
    if [ "$preset" = debug ]; then [ "$BUILT_debug" = 1 ] && return 0
    else [ "$BUILT_release" = 1 ] && return 0
    fi
    need cmake "Install CMake 3.20+."
    need ninja "Install ninja (apt install ninja-build / brew install ninja)."
    dir="$ROOT/build/$preset"
    if [ "$preset" = debug ]; then cmake_type=Debug; else cmake_type=Release; fi
    extra=(-DXAPIAN_BUILD_PYTHON3=OFF)
    [ "$OPT_python3" = 1 ] && extra=(-DXAPIAN_BUILD_PYTHON3=ON)
    say "configure ($preset)"
    cmake -S "$ROOT" -B "$dir" -G Ninja -DCMAKE_BUILD_TYPE="$cmake_type" ${extra[@]+"${extra[@]}"}
    say "build ($preset)"
    cmake --build "$dir" --parallel "$(ncpu)"
    if [ "$preset" = debug ]; then BUILT_debug=1; else BUILT_release=1; fi
}

# ---------------------------------------------------------------------------
# command line

WANT_doctor=0 WANT_clean=0 WANT_import=0 WANT_build=0 WANT_test=0

OPT_build=release
OPT_import_version="$XAPIAN_VERSION"
OPT_python3=0
BUILD_TYPE=release

canon_command() {
    case "$1" in
        help|doctor|clean|import|build|test) echo "$1" ;;
        *) return 1 ;;
    esac
}

is_help() { case "$1" in help|--help|-help|-h|-\?) return 0 ;; esac; return 1; }

wanted() {
    case "$1" in
        doctor) [ "$WANT_doctor" = 1 ] ;; clean) [ "$WANT_clean" = 1 ] ;;
        import) [ "$WANT_import" = 1 ] ;; build) [ "$WANT_build" = 1 ] ;;
        test) [ "$WANT_test" = 1 ] ;;
        *) return 1 ;;
    esac
}

want() {
    case "$1" in
        doctor) WANT_doctor=1 ;; clean) WANT_clean=1 ;; import) WANT_import=1 ;;
        build) WANT_build=1 ;; test) WANT_test=1 ;;
    esac
}

opt_name() {
    case "$1" in
        --*) printf '%s' "${1#--}" ;;
        -*) printf '%s' "${1#-}" ;;
        *) printf '%s' "$1" ;;
    esac
}

show_help_if_asked() {
    local a asked=0 names="" c n=0
    for a in "$@"; do
        if is_help "$a"; then asked=1; continue; fi
        if c="$(canon_command "$a")"; then
            case " $names " in *" $c "*) ;; *) names="$names $c"; n=$((n + 1)) ;; esac
        fi
    done
    [ "$asked" = 1 ] || return 0
    if [ "$n" = 1 ]; then help_cmd "${names# }"
    else help_main
    fi
    exit 0
}

parse_args() {
    local cur="" a n c
    while [ $# -gt 0 ]; do
        a="$1"
        shift
        if c="$(canon_command "$a")"; then
            wanted "$c" && usage_die "'$c' appears twice"
            want "$c"
            cur="$c"
            continue
        fi
        [ -n "$cur" ] || usage_die "unknown command '$a'"
        n="$(opt_name "$a")"
        case "$cur" in
            doctor|clean|test)
                usage_die "$cur: takes no options, got '$a'" "$cur" ;;
            build)
                case "$n" in
                    release|debug) OPT_build="$n" ;;
                    python3) OPT_python3=1 ;;
                    *) usage_die "build: unknown option '$a'" build ;;
                esac ;;
            import)
                case "$n" in
                    [0-9]*.[0-9]*.[0-9]*) OPT_import_version="$n" ;;
                    *) usage_die "import: unknown option '$a' (want X.Y.Z)" import ;;
                esac ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# commands

cmd_doctor() {
    local t v
    say "tools ($(os_name))"
    for t in cmake ninja c++ g++ clang++ curl tar pkg-config; do
        if command -v "$t" >/dev/null 2>&1; then
            v="$("$t" --version 2>/dev/null | head -n 1 || true)"
            printf '  %-12s %s  %s%s%s\n' "$t" "$(command -v "$t")" "$E_D" "$v" "$E_0" >&2
        else
            printf '  %-12s %smissing%s\n' "$t" "$E_Y" "$E_0" >&2
        fi
    done
    if [ "$(uname -s)" = Linux ] && command -v pkg-config >/dev/null 2>&1; then
        say "libraries (pkg-config)"
        for t in zlib uuid; do
            if v="$(pkg-config --modversion "$t" 2>/dev/null)"; then
                printf '  %-12s %s\n' "$t" "$v" >&2
            else
                printf '  %-12s %smissing%s\n' "$t" "$E_Y" "$E_0" >&2
            fi
        done
        printf '  %s(Linux: apt install ninja-build zlib1g-dev uuid-dev)%s\n' "$E_D" "$E_0" >&2
    fi
    for pkg in xapian-core xapian-omega xapian-bindings; do
        case "$pkg" in
            xapian-core) marker="include/xapian.h" ;;
            xapian-omega) marker="omega.cc" ;;
            xapian-bindings) marker="python3/xapian_wrap.cc" ;;
        esac
        if [ -f "$ROOT/third_party/$pkg/$marker" ]; then
            say "$pkg: third_party/$pkg"
        else
            warn "third_party/$pkg missing (CMake may download $XAPIAN_VERSION, or run $SELF import)"
        fi
    done
}

cmd_clean() {
    say "removing build/"
    rm -rf "$ROOT/build"
}

cmd_import() {
    need python3 "import runs scripts/import-xapian.py."
    say "import xapian-core + omega + bindings $OPT_import_version"
    python3 "$ROOT/scripts/import-xapian.py" --version "$OPT_import_version"
    ok "imported third_party/xapian-{core,omega,bindings} $OPT_import_version"
}

cmd_build() {
    ensure_built "$OPT_build"
    bits="libxapian + tools + omega"
    [ "$OPT_python3" = 1 ] && bits="$bits + python3"
    ok "built build/$OPT_build/ ($bits)"
}

cmd_test() {
    local dir="$ROOT/build/$BUILD_TYPE"
    ensure_built "$BUILD_TYPE"
    say "smoke test ($BUILD_TYPE)"
    ctest --test-dir "$dir" --output-on-failure
    ok "tests passed"
}

# ---------------------------------------------------------------------------

set -- ${ARGS[@]+"${ARGS[@]}"}
if [ $# -eq 0 ]; then
    help_main
    exit 0
fi
show_help_if_asked "$@"
parse_args "$@"

[ "$WANT_build" = 1 ] && BUILD_TYPE="$OPT_build"

PLAN=""
for c in $ORDER; do
    wanted "$c" && PLAN="$PLAN $c"
done
PLAN="${PLAN# }"
TOTAL=0
for c in $PLAN; do TOTAL=$((TOTAL + 1)); done

if [ "$TOTAL" -gt 1 ]; then
    say "plan: ${PLAN// / > }"
fi

i=0
for c in $PLAN; do
    i=$((i + 1))
    if [ "$TOTAL" -gt 1 ]; then
        printf '\n%s==> [%d/%d] %s%s\n' "$E_C" "$i" "$TOTAL" "$c" "$E_0" >&2
    fi
    "cmd_$c"
done
