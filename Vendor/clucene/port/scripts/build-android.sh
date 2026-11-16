#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STEP="${1:-help}"
ABI="${2:-arm64-v8a}"
JOBS="${JOBS:-4}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-android-23}"
ANDROID_STL="${ANDROID_STL:-c++_shared}"
CLUCENE_BUILD_HIGHLIGHTER="${CLUCENE_BUILD_HIGHLIGHTER:-OFF}"

usage() {
    printf '%s\n' \
        'Usage: bash scripts/build-android.sh <configure|build|install|package|all> [arm64-v8a|x86_64]' \
        'ANDROID_NDK_HOME must point to an installed NDK for configuration.' \
        'Outputs: build/android-<preset>, dist/android/<abi>' \
        'Overrides: JOBS, ANDROID_PLATFORM, ANDROID_STL, CLUCENE_BUILD_HIGHLIGHTER'
}

case "$STEP" in
    help|-h|--help) usage; exit 0 ;;
    configure|build|install|package|all) ;;
    *) usage >&2; exit 2 ;;
esac
case "$ABI" in
    arm64-v8a) PRESET=android-arm64 ;;
    x86_64) PRESET=android-x86_64 ;;
    *) usage >&2; exit 2 ;;
esac
if [[ ! "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
    printf '%s\n' 'JOBS must be a positive integer.' >&2
    exit 2
fi
if [[ "$ANDROID_STL" != c++_shared && "$ANDROID_STL" != c++_static ]]; then
    printf '%s\n' 'ANDROID_STL must be c++_shared or c++_static.' >&2
    exit 2
fi

cd "$ROOT"
BUILD_DIR="$ROOT/build/$PRESET"

configure() {
    command -v cmake >/dev/null || { printf '%s\n' 'CMake 3.21+ is required.' >&2; exit 1; }
    if [[ -z "${ANDROID_NDK_HOME:-}" ||
          ! -f "$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" ]]; then
        printf '%s\n' 'Set ANDROID_NDK_HOME to an installed NDK directory.' >&2
        exit 1
    fi
    cmake --preset "$PRESET" \
        "-DANDROID_PLATFORM=$ANDROID_PLATFORM" \
        "-DANDROID_STL=$ANDROID_STL" \
        "-DCLUCENE_BUILD_HIGHLIGHTER=$CLUCENE_BUILD_HIGHLIGHTER"
}

build() {
    cmake --build "$BUILD_DIR" --parallel "$JOBS"
}

install() {
    cmake --install "$BUILD_DIR" --prefix "$BUILD_DIR/install"
}

package() {
    if [[ ! -f "$BUILD_DIR/install/lib/libclucene.a" ||
          ! -f "$BUILD_DIR/install/include/CLucene.h" ]]; then
        printf 'Build and install %s before packaging.\n' "$ABI" >&2
        exit 1
    fi
    if [[ -e "$ROOT/dist/android/$ABI" ]]; then
        printf 'dist/android/%s exists; move or remove it before packaging again.\n' "$ABI" >&2
        exit 1
    fi
    mkdir -p "$ROOT/dist/android"
    cp -R "$BUILD_DIR/install" "$ROOT/dist/android/$ABI"
    printf 'Packaged %s. Link into your JNI library and use a consistent libc++ runtime.\n' "$ABI"
}

case "$STEP" in
    configure) configure ;;
    build) build ;;
    install) install ;;
    package) package ;;
    all) configure; build; install; package ;;
esac