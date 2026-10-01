#!/usr/bin/env bash
# Import an official xapian-core release tarball into third_party/xapian-core.
# Release tarballs include generated sources (Snowball, Lemon, exceptions, unicode).
set -euo pipefail

VERSION="${1:-2.1.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${ROOT}/third_party/xapian-core"
URL="https://oligarchy.co.uk/xapian/${VERSION}/xapian-core-${VERSION}.tar.xz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading ${URL}"
curl -fL --retry 5 --retry-connrefused -o "${TMP}/xapian-core.tar.xz" "${URL}"

echo "Extracting…"
tar -xJf "${TMP}/xapian-core.tar.xz" -C "${TMP}"

rm -rf "${DEST}"
mkdir -p "$(dirname "${DEST}")"
mv "${TMP}/xapian-core-${VERSION}" "${DEST}"

cat > "${DEST}/FORCED_IMPORT.txt" <<EOF
Imported from ${URL}
Import date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
This tree is GPL-2.0-or-later (see COPYING).
Use cmake/skeleton as a starting point for an MSVC-native build; do not
require MSYS2/MinGW for compilation once the CMake port is complete.
EOF

echo "Imported xapian-core ${VERSION} -> ${DEST}"
echo "Next: copy/adapt cmake/skeleton into third_party/xapian-core or the repo root."
