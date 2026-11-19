# CLucene Mobile

This project packages CLucene 2.3.3.4 as a static iOS XCFramework, with an
Android NDK build path prepared for future use.

## iOS

Requires macOS, full Xcode with iOS SDKs, CMake 3.21+, and Make.
The default deployment target is iOS 15.6. Both device and simulator libraries
are arm64; running the simulator requires an Apple Silicon Mac.

Run from the repository root:

```sh
bash scripts/build-ios.sh
```

Output: `dist/CLucene.xcframework`, containing libraries and matching headers.
Select **Do Not Embed** when adding it to an app. Delete any existing
XCFramework distribution before rebuilding; the script does not overwrite it.

See [the build guide](docs/building.md) for details and
[PocketSword integration](docs/pocketsword-integration.md) for SWORD settings.

## Android

Requires CMake, Make, and an Android NDK selected through `ANDROID_NDK_HOME`.
The untested build path supports `arm64-v8a` and `x86_64`, one ABI per build.

```sh
bash scripts/build-android.sh all arm64-v8a
```

Intended output: `dist/android/arm64-v8a/`, containing a static archive and
headers for a consumer's JNI library, not a JNI library or AAR itself.
See [the Android steps](docs/building.md#android-future-build-path).

## Status

- iOS: an XCFramework has been generated; both archives were verified as arm64 with the required headers. Application linking and runtime behavior remain unverified.
- Android: build definitions and scripts are prepared but have not been tested.
- Licensing: module notices are recorded; some permission/provenance questions remain open in [the repository inventory](THIRD_PARTY_LICENSES.md).

## License

The primary [LICENSE](LICENSE) is Apache 2.0; it covers this port's own files.
CLucene files retain their existing Apache-or-LGPL offers. SwordKit uses CLucene
under the GNU Lesser General Public License, version 2.1, which is compatible with
GPL-2.0-only; it does not select the Apache option. The LGPL-2.1 text is
`Vendor/clucene/upstream/LGPL.license` in the SwordKit repository.
Bundled third-party code retains its own terms.

[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) covers the whole repository and
links to module-local records. The iOS script copies the
[binary notices](docs/distribution/THIRD_PARTY_LICENSES.txt), license,
[NOTICE](NOTICE), and [CHANGES.txt](CHANGES.txt) into `dist/`; distribute them with the XCFramework.

## Layout

```text
.
|- CMakeLists.txt      Shared build rules
|- CMakePresets.json   Platform settings
|- src/
|   |- core/           CLucene indexing, analysis, and search
|   |- shared/         Shared utilities and compatibility code
|   |- contribs/       Preserved optional contributors
|- include/            Public entry header
|- cmake/              Source lists and configuration templates
|- scripts/            Build and packaging scripts
|- tests/              Optional host smoke test
|- docs/               Build, integration, and distribution notices
|- build/              Ignored intermediate outputs
|- dist/               Ignored packaged artifacts
```
