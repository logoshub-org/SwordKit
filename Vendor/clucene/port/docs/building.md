# Building CLucene Mobile

## Before the first build

Run all commands from the repository root. The iOS build requires macOS, CMake
3.21 or newer, Make, and full Xcode with the iPhoneOS and iPhoneSimulator SDKs.
An exact minimum Xcode version has not yet been verified for this older source.

The scripts don't delete old distribution outputs. Move or remove an existing
destination yourself before rebuilding. Build scripts have not been executed as
part of these script changes; compiler and runtime compatibility remain unverified.

## iOS: one command

```sh
bash scripts/build-ios.sh
```

No step names or device identifiers are needed. The script automatically
configures, compiles, installs, and packages two Release libraries using libc++:

- iOS device: arm64, using the iPhoneOS SDK.
- iOS simulator: arm64, using the iPhoneSimulator SDK.

The default minimum iOS version is 15.6. No connected iPhone is needed to build.
Running the arm64 simulator library requires an Apple Silicon Mac.

### Intended output

`dist/CLucene.xcframework` is the library package to add to PocketSword. It
contains both libraries and their matching headers. Xcode selects the device
library for an iPhone/iPad build or the simulator library for a simulator build.
Both are arm64, but they target different platforms and cannot be interchanged
or combined with `lipo`. Intel simulator support is intentionally excluded.

The package must be distributed with these accompanying documents:

```text
dist/LICENSE-CLucene
dist/NOTICE
dist/THIRD_PARTY_LICENSES.txt
dist/CHANGES.txt
```

Their tracked source copies are `LICENSE`, `NOTICE`, and `CHANGES.txt` at the
repository root, plus `docs/distribution/THIRD_PARTY_LICENSES.txt`. The
repository-wide inventory is [THIRD_PARTY_LICENSES.md](../THIRD_PARTY_LICENSES.md).
The script copies the binary-package documents into `dist/`
after packaging. Unicode 4.0 table provenance remains to be reconciled; see the
third-party document's official archive links before publication. Passing a
build is not a license-clearance check. Preserve applicable notices in the
consuming app's acknowledgements or associated distribution materials too.

No Swift interfaces, module map, dynamic framework, or app signing are required
for this C++ static-library package.

### Where configuration and intermediate files go

Configuration is an automatic CMake step, not a file you provide. It generates
`CMakeCache.txt`, Makefiles, and configuration headers inside each build directory:

```text
build/ios-device/               Device configuration and compiled objects
build/ios-simulator/            Simulator configuration and compiled objects
```

Each directory also contains:

```text
generated/include/CLucene/      Generated configuration headers
install/lib/libclucene.a        Compiled library staged for packaging
install/include/                Matching headers staged for packaging
```

These are ignored intermediate outputs. The source build rules remain in
`CMakeLists.txt` and platform settings remain in `CMakePresets.json`.

### Inspect and verify

```sh
plutil -p dist/CLucene.xcframework/Info.plist
xcrun lipo -info build/ios-device/install/lib/libclucene.a
xcrun lipo -info build/ios-simulator/install/lib/libclucene.a
```

Expect separate iOS and iOS-simulator entries, both arm64. These checks do not
replace linking into an app and exercising indexing and searching on a simulator
and physical device. See [PocketSword integration](pocketsword-integration.md).

### Overrides and repeated builds

```sh
IOS_DEPLOYMENT_TARGET=15.6 CLUCENE_BUILD_HIGHLIGHTER=ON \
  bash scripts/build-ios.sh
```

To change the number of parallel build jobs:

```sh
JOBS=8 bash scripts/build-ios.sh
```

The script applies the same deployment target and feature selection to both slices.
The archive includes core and shared code; highlighter code joins that same
archive when enabled. Its headers are installed only when enabled.

For command usage without building, use `bash scripts/build-ios.sh --help`.

To inspect the source through Xcode, generate a disposable project rather than
maintaining another source list:

```sh
cmake -S . -B build/ios-xcode -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.6
```

Use the normal presets/scripts for the packaging workflow. Do not change the
generator of an existing build directory.

## Android: future build path

Android has not been built or tested. Install an Android NDK and select it using
an environment variable; no developer-specific SDK path is committed:

```sh
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/<installed-version>"
bash scripts/build-android.sh configure arm64-v8a
bash scripts/build-android.sh build arm64-v8a
bash scripts/build-android.sh install arm64-v8a
bash scripts/build-android.sh package arm64-v8a
```

The preset uses the NDK's `build/cmake/android.toolchain.cmake`, API 23, and
`c++_shared`. The static archive is position-independent for linking into a JNI
shared library. Match the API requirement and C++ runtime to the consuming app:

```sh
ANDROID_PLATFORM=android-23 ANDROID_STL=c++_shared \
  bash scripts/build-android.sh configure arm64-v8a
```

Repeat with `x86_64` when Android emulator support is needed. That Android preset
does not add Intel simulator support to the iOS XCFramework.

```text
build/android-arm64/install/      arm64-v8a archive and headers
build/android-x86_64/install/     x86_64 archive and headers
dist/android/arm64-v8a/           distribution copy of install tree
dist/android/x86_64/              distribution copy of install tree
```

The package does not include `libc++_shared.so`; the consuming Android project
must package the matching NDK runtime when using `c++_shared`. Avoid multiple
static C++ runtimes across interacting shared libraries. JNI, Gradle, AAR, and
Prefab packaging belong to a future integration layer, not the CLucene core.

## Optional host smoke test

The host test creates an in-memory index and searches it. It is not enabled in
mobile presets, and cannot validate device-specific behavior.

```sh
cmake --preset host-debug
cmake --build build/host-debug --parallel 4
ctest --test-dir build/host-debug --output-on-failure
```

## Build ownership and dependencies

- `cmake/Sources.cmake` is the explicit implementation list for all platforms.
- Core and shared implementations form one archive; do not also compile either
  preserved monolithic source file.
- `src/core/CLucene/search/FilterResultCache.cpp` is an unused, incomplete template
  implementation and is intentionally excluded, matching the original monolithic
  build. The source is preserved, not implemented or repaired by this build.
- `src/shared/CLucene/util/deflate.cpp` is a preserved, incomplete bundled zlib
  implementation and is intentionally excluded. Link SDK/NDK zlib instead.
- Contributor analyzers, Snowball, and gzip streams are preserved but not yet
  configured; highlighter is the only currently selectable contributor.
- Public headers preserve `CLucene/...` paths. Installation includes some legacy
  support headers for compatibility; this is not yet a strict public/private API
  cleanup. The internal generated `_clucene-config.h` is not distributed.
- The generated mobile configuration templates retain inherited POSIX capability
  assumptions. Review those assumptions before claiming another platform or NDK
  version is supported. libc++, exceptions, wchar_t-based TCHAR, and Unicode
  settings must remain compatible between the library and consumers.
- CMake consumers can use `add_subdirectory` and link `CLucene::clucene`. Installed
  packages also expose `find_package(CLucene CONFIG REQUIRED)` and that target.
- Xcode consumers must additionally link libc++ and zlib; an XCFramework does
  not carry CMake's transitive link dependencies or preprocessor definitions.