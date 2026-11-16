#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Logos Hub Ltd
#
# Builds build/CLucene.xcframework from Vendor/clucene (assembled first: upstream + patches + port; Tools/assemble_clucene.sh) (static libraries for the iOS device and the simulator, arm64), zips it for a
# release and writes build/CLUCENE-BUILD-INFO.json. CLucene does not change, so this is run once; run it again only if its source changes,
# and then give the result a release of its own (clucene-<version>; docs/RELEASING.md).
#
# Usage: Tools/build_clucene_xcframework.sh      (needs cmake and Xcode)

set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CL="$ROOT/build/clucene-work"
OUT="$ROOT/build/CLucene.xcframework"
ZIP="$ROOT/build/CLucene.xcframework.zip"
LOG="$ROOT/build/clucene-build.log"
DEPLOY=${IOS_DEPLOYMENT_TARGET:-15.6}

# CLucene's own script builds inside its tree and will not overwrite: assemble a fresh tree under build/
rm -rf "$CL" "$OUT" "$ZIP"
mkdir -p "$ROOT/build"
"$ROOT/Tools/assemble_clucene.sh" "$CL" >/dev/null
if ! IOS_DEPLOYMENT_TARGET=$DEPLOY JOBS=$(sysctl -n hw.ncpu) bash "$CL/scripts/build-ios.sh" >"$LOG" 2>&1; then
	tail -25 "$LOG" >&2
	echo "the CLucene build failed (full log: $LOG)" >&2
	exit 1
fi
cp -R "$CL/dist/CLucene.xcframework" "$OUT"
# the licences travel with the binary: CLucene's own terms, then the port's
mkdir -p "$OUT/licenses"
cp "$ROOT/Vendor/clucene/upstream/COPYING" "$ROOT/Vendor/clucene/upstream/LGPL.license" "$ROOT/Vendor/clucene/upstream/APACHE.license" "$OUT/licenses/"
cp "$ROOT/Vendor/clucene/port/LICENSE" "$ROOT/Vendor/clucene/port/NOTICE" "$ROOT/Vendor/clucene/port/THIRD_PARTY_LICENSES.md" "$OUT/licenses/"
(cd "$ROOT/build" && ditto -c -k --sequesterRsrc --keepParent CLucene.xcframework CLucene.xcframework.zip)
CHECKSUM=$(swift package compute-checksum "$ZIP")

VERSION=$(sed -n 's/^#define _CL_VERSION *"\(.*\)"/\1/p' "$OUT/ios-arm64/Headers/CLucene/clucene-config.h")
UPSTREAM=$(grep -v '^#' "$ROOT/Vendor/UPSTREAM-clucene.txt" | head -1)
PATCHES=$(cat "$ROOT"/Vendor/clucene/patches/*.patch "$ROOT/Vendor/clucene/patches/excluded-upstream-files.txt" | shasum -a 256 | cut -d' ' -f1)
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
cat > "$ROOT/build/CLUCENE-BUILD-INFO.json" <<JSON
{
  "clucene": "$VERSION",
  "upstream": "$UPSTREAM",
  "patches sha256": "$PATCHES",
  "built": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "libclucene.a sha256, ios-arm64": "$(sha "$OUT/ios-arm64/libclucene.a")",
  "libclucene.a sha256, ios-arm64-simulator": "$(sha "$OUT/ios-arm64-simulator/libclucene.a")",
  "xcode": "$(xcodebuild -version | tr '\n' ' ' | sed 's/ *$//')",
  "cmake": "$(cmake --version | head -1)",
  "deployment-target": "$DEPLOY",
  "zip-checksum": "$CHECKSUM"
}
JSON

echo "built $OUT (CLucene $VERSION)"
echo "zip   $ZIP"
echo "info  $ROOT/build/CLUCENE-BUILD-INFO.json"
echo "checksum for Package.swift (CLucene): $CHECKSUM"
