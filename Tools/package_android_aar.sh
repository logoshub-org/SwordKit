#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Logos Hub Ltd
#
# Builds the Android release: for each ABI (arm64-v8a and x86_64) CLucene and then libsword_android.so, stripped; then the AAR and its
# Maven files (the Kotlin API in Android/sword and its keep rules, the licences, both ABIs' libraries).
#
# Output, in build/android-release/:
#   maven/org/logoshub/{sword,sword-okhttp}/<version>/*.aar (with .pom, .module, the sources jar): a Maven repository folder
#   SwordKit-android-<version>-maven.zip   that folder, zipped
#   sword-<version>-symbols.zip   the unstripped libraries, for reading crash traces (ndk-stack)
#
# Needs ANDROID_NDK_HOME, ANDROID_HOME, JAVA_HOME (a JDK 17 or later), cmake, and zip.
# Usage: Tools/package_android_aar.sh <version>        e.g. 1.2.3   (a local build: 0.0.0-local)

set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${1:-0.0.0-local}
ABIS="arm64-v8a x86_64"
OUT="$ROOT/build/android-release"
: "${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME}"
STRIP=$(find "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt" -name llvm-strip | head -1)
[ -n "$STRIP" ] || { echo "no llvm-strip in the NDK" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT/jniLibs" "$OUT/symbols"
[ -d "$ROOT/build/clucene-android" ] || "$ROOT/Tools/assemble_clucene.sh" "$ROOT/build/clucene-android" >/dev/null
for ABI in $ABIS; do
	[ -f "$ROOT/build/clucene-android/dist/android/$ABI/lib/libclucene.a" ] ||
		(cd "$ROOT/build/clucene-android" && bash scripts/build-android.sh all "$ABI" >"$ROOT/build/clucene-android-$ABI.log" 2>&1)
	"$ROOT/Tools/build_sword_android.sh" "$ABI"
	mkdir -p "$OUT/jniLibs/$ABI" "$OUT/symbols/$ABI"
	for LIB in libsword_android.so libc++_shared.so; do
		cp "$ROOT/build/android/$ABI/$LIB" "$OUT/symbols/$ABI/"
		"$STRIP" -o "$OUT/jniLibs/$ABI/$LIB" "$ROOT/build/android/$ABI/$LIB"
	done
done

rm -rf "$ROOT/Android/build/maven"
(cd "$ROOT/Android" && ./gradlew --no-daemon -q -PswordJniLibs="$OUT/jniLibs" -PswordKitVersion="$VERSION" \
	:sword:publishReleasePublicationToReleaseRepository :sword-okhttp:publishReleasePublicationToReleaseRepository)
cp -R "$ROOT/Android/build/maven" "$OUT/maven"
(cd "$OUT/symbols" && zip -qr "$OUT/sword-$VERSION-symbols.zip" .)
(cd "$OUT/maven" && zip -qr "$OUT/SwordKit-android-$VERSION-maven.zip" .)
echo "built $OUT/maven/org/logoshub/sword/$VERSION/sword-$VERSION.aar and sword-okhttp"
