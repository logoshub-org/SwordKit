# Releasing

The normal way: Actions tab, Release, Run workflow, with the version (`.github/workflows/release.yml`). It reuses the `clucene-2.3.3.4`
release if it exists (builds and publishes it if not), builds SwordCore against it, writes both URLs and checksums into `Package.swift`
(`Tools/update_manifest.py`), builds the package for the simulator and a device, commits, tags and creates the release. It needs the
repository's workflow permission "Read and write" and the Xcode named in `XCODE_APP` on the runner (check it before the first run).
The steps below are what it does, for doing it by hand.

## CLucene, once

CLucene does not change, so its binary is built and released once, under a tag of its own that every SwordKit version names.

1. `Tools/build_clucene_xcframework.sh` (it assembles `Vendor/clucene` first: upstream, patches, port; `Tools/assemble_clucene.sh`). It prints `checksum for Package.swift (CLucene)` and writes `build/CLUCENE-BUILD-INFO.json`.
2. Create the GitHub release `clucene-2.3.3.4` (the CLucene version) and attach `build/CLucene.xcframework.zip` and `CLUCENE-BUILD-INFO.json`.
3. Put the checksum in `Package.swift`, on the `CLucene` binary target.

Build and release it again only if `Vendor/clucene` changes, or a new toolchain no longer links with it. Then it is a new tag
(`clucene-<version>`), `Package.swift` names it, and SwordCore is rebuilt against it (below).

## SwordKit, each release

1. Update what changed: `Vendor/sword` (sync it by hand; update `Vendor/UPSTREAM-sword.txt`), `Core/`, `Sources/`.
2. `Tools/build_sword_xcframework.sh build/CLucene.xcframework <SwordKit version>`. It prints `checksum for Package.swift (SwordCore)` and writes
   `build/BUILD-INFO.json`: the SwordKit version, SWORD's version and upstream revision, the CLucene it was built against (version and the
   checksum of each slice's `libclucene.a`), Xcode, cmake, the deployment target and the zip's checksum.
3. In `Package.swift` put the version's URL and that checksum. Copy `build/BUILD-INFO.json` to the repository root, so that the tag records its
   own inputs. Commit and tag the version.
4. Create the GitHub release for the tag; attach `build/SwordCore.xcframework.zip` and `BUILD-INFO.json`.

## Android, each release

The release workflow's `android` job runs after the iOS release is made: it installs the NDK, runs `Tools/package_android_aar.sh <version>`
(CLucene and SWORD for arm64-v8a and x86_64, stripped; the AARs for `sword` and `sword-okhttp`), and attaches to the release
`sword-<version>.aar`, `sword-okhttp-<version>.aar`, `SwordKit-android-<version>-maven.zip` (a Maven repository folder) and
`sword-<version>-symbols.zip` (the unstripped libraries: keep it, crash traces need it). If the job fails, use "Re-run failed jobs": the
upload replaces what it made. Run the instrumented tests first (`Tools/run_android_tests.sh`): the workflow builds, it does not test.

## In the app, after a release

1. Update the package (File, Packages, Update to Latest Package Versions).
2. Run the SWORD tests on a simulator, above all the search ones (`SwordSearchIndexTests` builds a CLucene index and searches it): a
   header or ABI mismatch can compile and link and still misbehave.

## Keeping the two binaries matched

Both come from this repository, so SwordCore is built against the headers of the CLucene in the same commit. The one thing to watch is
that SwordCore and the CLucene binary come from compatible toolchains: if a new Xcode makes them stop linking, or search misbehaves,
rebuild CLucene too. `BUILD-INFO.json` (SwordCore) and `CLUCENE-BUILD-INFO.json` (CLucene) record the Xcode and the library checksums, so
the two can be compared.
