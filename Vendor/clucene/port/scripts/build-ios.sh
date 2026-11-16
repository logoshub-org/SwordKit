#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JOBS="${JOBS:-4}"
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-15.6}"
CLUCENE_BUILD_HIGHLIGHTER="${CLUCENE_BUILD_HIGHLIGHTER:-OFF}"

usage() {
    printf '%s\n' \
        'Usage: bash scripts/build-ios.sh' \
        'Configures, builds, installs, and packages arm64 iOS device and simulator libraries.' \
        'Outputs: build/ios-device, build/ios-simulator, dist/CLucene.xcframework' \
        'Overrides: JOBS, IOS_DEPLOYMENT_TARGET, CLUCENE_BUILD_HIGHLIGHTER'
}

if [[ $# -eq 1 && ( "$1" == -h || "$1" == --help ) ]]; then
    usage
    exit 0
fi
if [[ $# -ne 0 ]]; then
    usage >&2
    exit 2
fi
if [[ ! "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
    printf '%s\n' 'JOBS must be a positive integer.' >&2
    exit 2
fi

cd "$ROOT"

command -v cmake >/dev/null || { printf '%s\n' 'CMake 3.21+ is required.' >&2; exit 1; }
xcrun --sdk iphoneos --show-sdk-path >/dev/null
xcrun --sdk iphonesimulator --show-sdk-path >/dev/null
if [[ -e "$ROOT/dist/CLucene.xcframework" ]]; then
    printf '%s\n' 'dist/CLucene.xcframework exists; move or remove it before rebuilding.' >&2
    exit 1
fi

for PRESET in ios-device ios-simulator; do
    printf '\nBuilding %s (arm64)...\n' "$PRESET"
    cmake --preset "$PRESET" \
        "-DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_DEPLOYMENT_TARGET" \
        "-DCLUCENE_BUILD_HIGHLIGHTER=$CLUCENE_BUILD_HIGHLIGHTER"
    cmake --build "$ROOT/build/$PRESET" --parallel "$JOBS"
    cmake --install "$ROOT/build/$PRESET" --prefix "$ROOT/build/$PRESET/install"
done

mkdir -p "$ROOT/dist"
xcodebuild -create-xcframework \
    -library "$ROOT/build/ios-device/install/lib/libclucene.a" \
    -headers "$ROOT/build/ios-device/install/include" \
    -library "$ROOT/build/ios-simulator/install/lib/libclucene.a" \
    -headers "$ROOT/build/ios-simulator/install/include" \
    -output "$ROOT/dist/CLucene.xcframework"
cp "$ROOT/LICENSE" "$ROOT/dist/LICENSE-CLucene"
cp "$ROOT/NOTICE" "$ROOT/docs/distribution/THIRD_PARTY_LICENSES.txt" "$ROOT/CHANGES.txt" "$ROOT/dist/"
printf '\nBuilt %s\n' "$ROOT/dist/CLucene.xcframework"