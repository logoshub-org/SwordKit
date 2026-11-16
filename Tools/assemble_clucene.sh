#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Logos Hub Ltd
#
# Assembles the CLucene tree that is built: the pristine upstream sources (Vendor/clucene/upstream), minus the upstream build files the
# port replaces (patches/excluded-upstream-files.txt), plus the patches (patches/*.patch, in name order), plus the port (CMake, scripts,
# headers, licence notes: Vendor/clucene/port). The result is written to the directory given (it must not exist).
#
# Usage: Tools/assemble_clucene.sh <work-dir>

set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CL="$ROOT/Vendor/clucene"
WORK=${1:?usage: assemble_clucene.sh <work-dir>}
[ ! -e "$WORK" ] || { echo "$WORK exists; remove it first" >&2; exit 1; }

mkdir -p "$WORK/src"
cp -R "$CL/upstream/src/core" "$WORK/src/core"
cp -R "$CL/upstream/src/shared" "$WORK/src/shared"
cp -R "$CL/upstream/src/contribs-lib" "$WORK/src/contribs"
while read -r f; do
	[ -z "$f" ] || rm -rf "$WORK/src/$f"
done < "$CL/patches/excluded-upstream-files.txt"
for p in "$CL"/patches/*.patch; do
	(cd "$WORK" && patch -p1 -s --no-backup-if-mismatch < "$p") || { echo "patch failed: $p" >&2; exit 1; }
done
# the port: its files at the root, its licence notes into src/
for f in "$CL"/port/*; do
	[ "$(basename "$f")" = overlay ] || cp -R "$f" "$WORK/"
done
cp -R "$CL/port/overlay/src/." "$WORK/src/"
# the upstream licence texts travel with the source
for f in COPYING LGPL.license APACHE.license AUTHORS; do cp "$CL/upstream/$f" "$WORK/$f"; done
echo "assembled $WORK"
