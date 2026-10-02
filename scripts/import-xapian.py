#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Import Xapian module sources into third_party/.

Official release tarballs (core / omega / bindings) come from oligarchy.co.uk.
xapian-letor is only published in the git monorepo, so it is fetched from the
matching GitHub tag.

Usage:
  python scripts/import-xapian.py              # all packages
  python scripts/import-xapian.py core omega  # subset
  python scripts/import-xapian.py --version 2.1.0 letor
"""
from __future__ import annotations

import argparse
import datetime
import os
import shutil
import sys
import tarfile
import tempfile
import urllib.request

PACKAGES = ("core", "omega", "bindings", "letor")
DEFAULT_VERSION = "2.1.0"


def pkg_name(short: str) -> str:
    return f"xapian-{short}"


def _stamp(dest: str, url: str) -> None:
    stamp = os.path.join(dest, "FORCED_IMPORT.txt")
    when = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(stamp, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"Imported from {url}\n")
        f.write(f"Import date: {when}\n")
        f.write("This tree is GPL-2.0-or-later (see COPYING).\n")


def import_release_tarball(root: str, short: str, version: str) -> None:
    name = pkg_name(short)
    dest = os.path.join(root, "third_party", name)
    url = f"https://oligarchy.co.uk/xapian/{version}/{name}-{version}.tar.xz"
    print(f"Downloading {url}")
    with tempfile.TemporaryDirectory(prefix=f"xapian-import-{short}-") as tmp:
        archive = os.path.join(tmp, f"{name}.tar.xz")
        urllib.request.urlretrieve(url, archive)
        print(f"Extracting {name}…")
        with tarfile.open(archive, "r:xz") as tar:
            tar.extractall(tmp)
        extracted = os.path.join(tmp, f"{name}-{version}")
        if not os.path.isdir(extracted):
            raise SystemExit(f"expected directory {extracted} after extract")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        if os.path.exists(dest):
            shutil.rmtree(dest)
        shutil.move(extracted, dest)
    _stamp(dest, url)
    print(f"Imported {name} {version} -> third_party/{name}")


def import_letor_from_github(root: str, version: str) -> None:
    """Pull xapian-letor out of the monorepo tag (no standalone release tarball)."""
    dest = os.path.join(root, "third_party", "xapian-letor")
    url = f"https://codeload.github.com/xapian/xapian/tar.gz/v{version}"
    print(f"Downloading {url} (monorepo; extracting xapian-letor only)")
    with tempfile.TemporaryDirectory(prefix="xapian-import-letor-") as tmp:
        archive = os.path.join(tmp, "xapian.tar.gz")
        urllib.request.urlretrieve(url, archive)
        print("Extracting…")
        with tarfile.open(archive, "r:gz") as tar:
            members = [
                m
                for m in tar.getmembers()
                if "/xapian-letor/" in m.name.replace("\\", "/")
                or m.name.replace("\\", "/").endswith("/xapian-letor")
            ]
            if not members:
                raise SystemExit("xapian-letor/ not found in monorepo archive")
            tar.extractall(tmp, members=members)
        # Archive root is typically xapian-<version>/
        extracted = None
        for name in os.listdir(tmp):
            candidate = os.path.join(tmp, name, "xapian-letor")
            if os.path.isdir(candidate):
                extracted = candidate
                break
        if extracted is None:
            raise SystemExit("could not locate extracted xapian-letor directory")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        if os.path.exists(dest):
            shutil.rmtree(dest)
        shutil.move(extracted, dest)
    _stamp(dest, url)
    # Generate exception headers that autotools would ship in a release tarball.
    gen = os.path.join(root, "scripts", "generate-letor-exceptions.py")
    if os.path.isfile(gen):
        import subprocess

        subprocess.check_call([sys.executable, gen, "--outdir", os.path.join(dest, "include", "xapian-letor")])
    print(f"Imported xapian-letor {version} -> third_party/xapian-letor")


def import_one(root: str, short: str, version: str) -> None:
    if short == "letor":
        import_letor_from_github(root, version)
    else:
        import_release_tarball(root, short, version)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "packages",
        nargs="*",
        choices=PACKAGES + ("all",),
        help="packages to import (default: all)",
    )
    ap.add_argument("--version", default=DEFAULT_VERSION, help="release version")
    args = ap.parse_args(argv)
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    wanted = list(args.packages) if args.packages else ["all"]
    if "all" in wanted:
        wanted = list(PACKAGES)
    for short in wanted:
        import_one(root, short, args.version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
