# SwordKit

The [SWORD](https://crosswire.org/sword/) Bible engine and its search library CLucene, ready to use in an iOS or Android app.

Add one Swift package (iOS 17 and later) or one Android library, and your app can read installed SWORD modules (Bibles, commentaries,
dictionaries), search them, and download and install more from CrossWire's repositories. SwordKit ships the compiled engine for you, so
there is no C++ to build.

## What you get

- **Reading:** chapters, passages and dictionary entries from installed modules, as raw markup or plain text; module facts (language,
  versification, direction, cipher); locked modules.
- **Search:** a regular-expression search, and CLucene's indexed search (phrases, `&&`, `||`, Strong's `lemma:`) once an index is built.
- **Installing modules:** SWORD's install manager over HTTPS, using your platform's own network stack (`URLSession` on iOS, OkHttp on Android),
  so there is no curl to ship. Progress and cancellation are reported.
- **Versification and passages:** book lists and verse counts for each versification system, and passage parsing.

## iOS

In Xcode: File, Add Package Dependencies, enter `https://github.com/logoshub-org/SwordKit`, choose a version, and add the
**SwordProvider** library to your app target.

Or in a `Package.swift`:

```swift
.package(url: "https://github.com/logoshub-org/SwordKit.git", from: "0.1.0")
// then: .product(name: "SwordProvider", package: "SwordKit")
```

SwordProvider is a Swift API over two prebuilt binaries, `SwordCore.xcframework` (SWORD) and `CLucene.xcframework`, which Swift Package
Manager downloads from this repository's releases.

## Android

arm64-v8a and x86_64, minimum API 23. Each release has `SwordKit-android-<version>-maven.zip`: unpack it as a local Maven repository,
add that folder as a repository in Gradle, and depend on:

```kotlin
implementation("org.logoshub:sword-okhttp:<version>")   // brings org.logoshub:sword (the library) and OkHttp
```

Register the HTTP client once at startup with `SwordInstallManager.setHttpFetcher(OkHttpFetcher())`. The release also has the two AARs and a
zip of unstripped libraries for reading crash traces. If your app also bundles the C++ runtime, add
`packaging { jniLibs { pickFirsts += "**/libc++_shared.so" } }`. The core library is `org.logoshub:sword`; use it alone if you bring your own
HTTP client.

## Versions

SwordKit follows semantic versioning; its version is its own, not SWORD's. A release's title and `BUILD-INFO.json` record the SWORD and
CLucene versions inside it, for example "SwordKit 0.1.0 (SWORD 1.9.0.3981, CLucene 2.3.3.4)".

## Limits

- iOS has simulator and device slices only; tests need a simulator, not `swift test`.
- On Android, modules compressed with bzip2 do not open (the NDK has no libbz2); the others do.
- The Android x86_64 library is built and checked but has not been run on an emulator or device.

## Licence

SwordKit is a combined work under the GNU General Public License, version 2 only (GPL-2.0-only), because it includes SWORD. An app that
links it must be GPL-2.0-compatible. The full text is in [LICENSE](LICENSE); each component's terms, including CLucene (used under the
LGPL 2.1), are in [NOTICE](NOTICE).

## Working on SwordKit

Building the binaries, running the tests, making a release, and how the repository is laid out are in
[docs/DEVELOPING.md](docs/DEVELOPING.md) and [docs/RELEASING.md](docs/RELEASING.md). What the Android side offers, and what could be
offered to CrossWire, is in [docs/ANDROID-API.md](docs/ANDROID-API.md).
