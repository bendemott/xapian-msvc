#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Back-compat wrapper: prefer scripts/import-xapian.py
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-2.1.0}"
exec python3 "$ROOT/scripts/import-xapian.py" --version "$VERSION" core
