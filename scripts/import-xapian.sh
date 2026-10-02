#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Thin wrapper around scripts/import-xapian.py (needs Python 3 + lzma).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/scripts/import-xapian.py" "$@"
