#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Logos Hub Ltd
#
# Runs Android/sword's instrumented tests on the one emulator or device that adb sees: builds libsword_android.so, packages the test
# APK, pushes the test modules and runs them. The modules are local test data (never committed): a folder laid out as a SWORD library
# (mods.d and modules) holding KJV and a Strong's dictionary, for example the unpacked kjv31.zip and StrongsGreek.zip of
# ~/source/pocketsword-dumps/modules.
#
# Needs ANDROID_NDK_HOME, ANDROID_HOME (the SDK), JAVA_HOME (a JDK 17 or later: Android Studio's jbr), cmake, and a running emulator.
# Usage: Tools/run_android_tests.sh <module folder> [<abi>]

set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MODULES=${1:?usage: run_android_tests.sh <module folder> [abi]}
ABI=${2:-arm64-v8a}
ADB="${ANDROID_HOME:?set ANDROID_HOME}/platform-tools/adb"
[ -d "$MODULES/mods.d" ] || { echo "$MODULES has no mods.d" >&2; exit 1; }
"$ADB" get-state >/dev/null 2>&1 || { echo "no emulator or device: start one first" >&2; exit 1; }

[ -f "$ROOT/build/clucene-android/dist/android/$ABI/lib/libclucene.a" ] || {
	"$ROOT/Tools/assemble_clucene.sh" "$ROOT/build/clucene-android" >/dev/null
	(cd "$ROOT/build/clucene-android" && bash scripts/build-android.sh all "$ABI" >"$ROOT/build/clucene-android.log" 2>&1)
}
"$ROOT/Tools/build_sword_android.sh" "$ABI"
(cd "$ROOT/Android" && ./gradlew --no-daemon -q :sword:assembleDebugAndroidTest :sword-okhttp:assembleDebugAndroidTest)

"$ADB" shell "rm -rf /data/local/tmp/sword-test; mkdir -p /data/local/tmp/sword-test"
"$ADB" push "$MODULES/." /data/local/tmp/sword-test/ >/dev/null
"$ADB" shell "chmod -R a+rX /data/local/tmp/sword-test"
STATUS=0
for PAIR in "sword/build/outputs/apk/androidTest/debug/sword-debug-androidTest.apk org.logoshub.sword.test" \
            "sword-okhttp/build/outputs/apk/androidTest/debug/sword-okhttp-debug-androidTest.apk org.logoshub.sword.okhttp.test"; do
	set -- $PAIR
	"$ADB" install -r -t "$ROOT/Android/$1" >/dev/null
	OUT=$("$ADB" shell am instrument -w -r "$2/androidx.test.runner.AndroidJUnitRunner")
	echo "== $2"
	echo "$OUT" | grep -E "stack=|^OK|^FAILURES|^Tests run" || true
	echo "$OUT" | grep -q "^OK (" || STATUS=1
done
exit $STATUS
