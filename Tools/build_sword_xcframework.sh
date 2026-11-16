#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Logos Hub Ltd
#
# Builds build/SwordCore.xcframework from Core/ and Vendor/sword: SWORD and the C layer (sword_flat_ext) as a static library for the iOS
# device and the iOS simulator (arm64), with the C headers and the CSwordCore module map. Then zips it for a release, writes
# build/BUILD-INFO.json (what it was built from and against) and prints the checksum Package.swift needs.
#
# SWORD's search code is compiled against CLucene's headers, which come from CLucene.xcframework: build it first
# (Tools/build_clucene_xcframework.sh), or pass the path of the released one. SwordCore is not linked with CLucene: SwordProvider links both.
#
# Usage: Tools/build_sword_xcframework.sh [<path to CLucene.xcframework> [<SwordKit version>]]      (needs cmake)

set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CLUCENE=${1:-$ROOT/build/CLucene.xcframework}
SWORDKIT_VERSION=${2:-dev}
[ -d "$CLUCENE" ] || { echo "no CLucene xcframework at $CLUCENE: run Tools/build_clucene_xcframework.sh first, or pass the path of the released one" >&2; exit 1; }
CLUCENE=$(cd "$CLUCENE" && pwd)

CORE="$ROOT/Core"
OUT="$ROOT/build/SwordCore.xcframework"
ZIP="$ROOT/build/SwordCore.xcframework.zip"
WORK="${TMPDIR:-/tmp}/swordcore-build"
DEPLOY=17.6

rm -rf "$WORK" "$OUT" "$ZIP"
mkdir -p "$WORK/include" "$ROOT/build"
cp "$ROOT/Vendor/sword/include/flatapi.h" "$ROOT/Vendor/sword/include/defs.h" "$CORE/sword_flat_ext.h" "$WORK/include/"
# in the framework the headers sit beside the module map
sed 's#"../Vendor/sword/include/flatapi.h"#"flatapi.h"#' "$CORE/module.modulemap" > "$WORK/include/module.modulemap"

build() { # name sysroot cluceneslice
	cmake -S "$CORE" -B "$WORK/$1" -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$2" -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=$DEPLOY \
		-DCLUCENE_HEADERS="$CLUCENE/$3/Headers" >/dev/null
	cmake --build "$WORK/$1" -j "$(sysctl -n hw.ncpu)" >/dev/null
}
build device iphoneos ios-arm64
build simulator iphonesimulator ios-arm64-simulator

xcodebuild -create-xcframework \
	-library "$WORK/device/libsword.a" -headers "$WORK/include" \
	-library "$WORK/simulator/libsword.a" -headers "$WORK/include" \
	-output "$OUT"

# the licence travels with the binary
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$OUT/"
# SwiftPM wants the xcframework folder at the root of the zip
(cd "$ROOT/build" && ditto -c -k --sequesterRsrc --keepParent SwordCore.xcframework SwordCore.xcframework.zip)
CHECKSUM=$(swift package compute-checksum "$ZIP")

# what this binary was built from and against
SWORD_VERSION=$(sed -n 's/^#define SWORD_VERSION_STR "\(.*\)"/\1/p' "$ROOT/Vendor/sword/include/swversion.h")
SWORD_UPSTREAM=$(grep -v '^#' "$ROOT/Vendor/UPSTREAM-sword.txt" | head -1)
CLUCENE_VERSION=$(sed -n 's/^#define _CL_VERSION *"\(.*\)"/\1/p' "$CLUCENE/ios-arm64/Headers/CLucene/clucene-config.h")
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
cat > "$ROOT/build/BUILD-INFO.json" <<JSON
{
  "swordkit": "$SWORDKIT_VERSION",
  "built": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "sword": { "version": "$SWORD_VERSION", "upstream": "$SWORD_UPSTREAM" },
  "built against clucene": {
    "version": "$CLUCENE_VERSION",
    "libclucene.a sha256, ios-arm64": "$(sha "$CLUCENE/ios-arm64/libclucene.a")",
    "libclucene.a sha256, ios-arm64-simulator": "$(sha "$CLUCENE/ios-arm64-simulator/libclucene.a")"
  },
  "xcode": "$(xcodebuild -version | tr '\n' ' ' | sed 's/ *$//')",
  "cmake": "$(cmake --version | head -1)",
  "deployment-target": "$DEPLOY",
  "swordcore-zip-checksum": "$CHECKSUM"
}
JSON

echo "built $OUT"
echo "zip   $ZIP"
echo "info  $ROOT/build/BUILD-INFO.json"
echo "checksum for Package.swift (SwordCore): $CHECKSUM"
