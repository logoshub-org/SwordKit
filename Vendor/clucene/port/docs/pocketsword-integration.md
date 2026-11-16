# PocketSword integration

## Architecture

```text
PocketSword Objective-C++ wrappers -> SWORD C++ -> CLucene C++
```

PocketSword currently compiles SWORD source directly into its app. Its SWORD
configuration enables `USELUCENE`, and `swmodule.cpp` includes `<CLucene.h>`.
This repository now supplies that umbrella header and a static archive including
both CLucene core and shared utilities.

These are integration instructions, not changes applied to PocketSword.

## Link the XCFramework

1. Complete both iOS builds and package `dist/CLucene.xcframework` as described
   in [the build guide](building.md).
2. Add the XCFramework to the PocketSword app target's linked libraries. Select
   **Do Not Embed** because its payload is static. Do not additionally link an
   older CLucene archive or compile CLucene implementations into the app.
3. Remove the stale `externals/clucene/**` header search path. Verify Xcode makes
   the selected XCFramework slice's `Headers` directory available for
   `<CLucene.h>`. If an explicit header path is needed, select it by SDK; do not
   recursively search all slices or use this repository's source headers in
   preference to the packaged headers.
4. Link libc++ (`libc++.tbd`) and zlib (`libz.tbd`) in the final app target.
5. Set the app deployment target to at least the library's deployment target.
   Both presets default to PocketSword's existing iOS 15.6 minimum.

## SWORD compilation settings

Keep `USELUCENE=1` enabled and add `CLUCENE2=1` to SWORD's compilation settings.
The checked-in SWORD implementation has CLucene 2 API branches for directory
creation and `addIndexes`; this CLucene library is version 2.3.3.4.

Use compatible C++ settings in all relevant app/SWORD configurations:

```text
C++ language standard:       C++11 (or a newer, verified compatible standard)
C++ standard library:       libc++
C++ exceptions:             enabled
Preprocessor definitions:   CLUCENE2=1, _UCS2, _UNICODE,
                            MAKE_CLUCENE_CORE_LIB, MAKE_CLUCENE_SHARED_LIB
```

Preserve inherited definitions. `USELUCENE` may remain in SWORD's existing
configuration header instead of being duplicated as a compiler definition.
`_UCS2` is the inherited mode name: this port's public `TCHAR` is `wchar_t`, not a
promise of a two-byte character ABI. Do not change wchar_t size or mix ASCII
headers and Unicode binaries. The templates currently preserve hashing-disabled
behavior from `CLConfig.h`.

No Swift module map or new Objective-C wrapper is needed for SWORD to call
CLucene. Keep C++ calls in the existing `.mm` or `.cpp` files.

## Verify before shipping

- Link and launch on an arm64 simulator and a physical arm64 iOS device.
- Create a new search index and exercise SWORD's indexed/external search path.
- Test existing downloaded indexes; matching the CLucene version alone does not
  establish index-format compatibility with every previously produced index.
- Test multilingual text, phrase searches, and queries with punctuation.
- Confirm index files and locks are created under writable app-container paths.
- Rebuild or invalidate old indexes when compatibility testing shows it is needed.

Intel iOS simulator support is deliberately absent. Android linkage is separate
and does not change this iOS package or PocketSword's wrapper layer.