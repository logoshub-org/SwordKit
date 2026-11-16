#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Logos Hub Ltd
#
# Builds build/android/<abi>/libsword_android.so: SWORD, our C layer and CLucene in one shared library for Android. bzip2 is not
# supported yet (see Core/CMakeLists.txt): a module compressed with bzip2 will not open.
#
# Needs ANDROID_NDK_HOME, cmake and make or ninja. CLucene is the Android build of Vendor/clucene:
#   Tools/assemble_clucene.sh build/clucene-android && (cd build/clucene-android && bash scripts/build-android.sh all arm64-v8a)
#
# Usage: Tools/build_sword_android.sh [<abi> [<CLucene dist dir for that abi>]]
#        defaults: arm64-v8a, build/clucene-android/dist/android/<abi>

set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ABI=${1:-arm64-v8a}
CL=${2:-$ROOT/build/clucene-android/dist/android/$ABI}
PLATFORM=${ANDROID_PLATFORM:-android-23}
[ -f "${ANDROID_NDK_HOME:-}/build/cmake/android.toolchain.cmake" ] || { echo "set ANDROID_NDK_HOME to an installed NDK" >&2; exit 1; }
[ -f "$CL/lib/libclucene.a" ] || { echo "no CLucene for $ABI at $CL: build it first (see the header of this script)" >&2; exit 1; }
CL=$(cd "$CL" && pwd)
OUT="$ROOT/build/android/$ABI"
WORK="$ROOT/build/android-work/$ABI"
LOG="$ROOT/build/android-work/sword-$ABI.log"
rm -rf "$WORK" "$OUT"; mkdir -p "$WORK" "$OUT"

if ! { cmake -S "$ROOT/Core" -B "$WORK" -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" -DANDROID_ABI="$ABI" \
		-DANDROID_PLATFORM="$PLATFORM" -DANDROID_STL=c++_shared \
		-DCLUCENE_HEADERS="$CL/include" -DCLUCENE_LIB="$CL/lib/libclucene.a" \
	&& cmake --build "$WORK" --target sword_android --parallel "$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"; } >"$LOG" 2>&1; then
	grep -E "error|Error" "$LOG" | head -20 >&2
	echo "the build failed (full log: $LOG)" >&2
	exit 1
fi
cp "$WORK/libsword_android.so" "$OUT/"
# the C++ runtime the library was linked against travels with it
STL=$(find "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt" -path "*sysroot/usr/lib/*" -name libc++_shared.so | grep -E "/(aarch64|x86_64|arm|i686)-linux-android(eabi)?/" | grep -E "$( [ "$ABI" = arm64-v8a ] && echo aarch64 || echo x86_64 )" | head -1)
[ -z "$STL" ] || cp "$STL" "$OUT/"
echo "built $OUT/libsword_android.so"
