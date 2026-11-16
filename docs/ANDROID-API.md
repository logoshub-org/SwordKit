# Android API: what exists, what is ours, what to ask CrossWire for

`libsword_android.so` holds SWORD, CLucene, SWORD's flat C API (`flatapi.cpp`) and our C layer (`sword_flat_ext`, the 27 `swx_*`
functions), with one JNI file over the calls `SwordProvider` uses (`Core/android/sword_jni.cpp`, 38 functions). The Kotlin side is
`Android/sword` (`org.logoshub.sword`): `SwordNative` (the JNI), then `SwordLibrary`, `SwordVersification` and `SwordInstallManager`, the
same shape as the Swift `SwordProvider`. Only JNI, flat-API and `swx_*` names are exported (`Core/android/exports.map`).
The aim is the API that `SwordProvider` needs, and then to give the parts we maintain to CrossWire so that they are in the flat API
and a JNI binding, and we carry less.

**CrossWire's own JNI binding (`bindings/java-jni`) is not used.** It was built in once and removed (D181): it wraps SWORD's classes
(`SWMgr`, `SWModule`, `SWKey`, `InstallMgr`) as a second, separate world from the flat API that the `swx_*` calls and the Swift side
use (a handle from one is not valid in the other), has no HTTPS without curl, and brings BibleSync and shared-storage code that we do not
use. Going the flat API way gives Kotlin the same calls as Swift. If CrossWire's binding gains the pieces below, it can be looked at again.

Built without curl, BibleSync and bzip2 (the NDK has no libbz2; CrossWire's own Android build leaves it out too).

## What SwordProvider needs, and where it comes from

| SwordProvider needs | In CrossWire's JNI binding | Ours (`swx_*`) |
|---|---|---|
| open a library, list modules, one module's facts | `SWMgr` (`getModInfoList`, `getModuleByName`, `getConfigEntry`) | `swx_module_info`, `swx_module_config_entry`, `swx_module_has_feature` (facts in one call, and which features) |
| read text | `SWModule` `setKeyText`, `getRenderText`, `getStripText`, `getRawEntry`: one entry at a time | `swx_read_chapter` (a whole chapter, raw entries with their verse numbers), `swx_read_entry`, `swx_read_stripped` |
| dictionary keys | `SWKey` children, one at a time | `swx_dictionary_keys` (all keys at once) |
| versification | none | `swx_versification_books`, `swx_versification_systems`, `swx_english_book_name`, `swx_parse_passage` (the last is near `parseKeyList`) |
| search | `search`, `hasSearchFramework`, `deleteSearchFramework` (built without CLucene upstream, so no indexed search) | `swx_search`, `swx_create_search_index`, `swx_has_search_index` |
| install: list, refresh, install, remove | `InstallMgr` `getRemoteModuleByName`, `refreshRemoteSource`, `remoteInstallModule`, `uninstallModule`, `syncConfig` | `swx_install_sources`, `swx_install_add_source`, `swx_install_remove_source`, `swx_install_new`, `swx_install_delete` |
| install from a folder (a zip unpacked by the app) | none | `swx_install_from_folder` |
| **downloading** | SWORD's own transports: FTP, and HTTP through curl (not built) | `swx_set_http_fetch`: the host fetches each URL (URLSession on iOS; on Android HttpURLConnection or OkHttp through JNI) and `EBInstallMgr` hands it to SWORD as a transport |
| locale | `setDefaultLocale`, `getAvailableLocales` | `swx_init_locale` |

## Done, and not yet
- Done: the JNI and the Kotlin classes over the flat API and `swx_*`, including the host's HTTP fetch for the install manager
  (`SwordNative.HttpFetcher`). `Android/sword-okhttp` has `OkHttpFetcher` (one URL into memory, progress and cancel through the hooks,
  SWORD's error codes, basic auth, and an unverified certificate accepted only when SWORD asks, as on iOS). Seventeen instrumented tests
  pass on an arm64 emulator (Android 37): the nine of the core (modules, facts, chapters raw and plain, passages, regex and indexed
  search, dictionary entries, versification, Unicode beyond the BMP across JNI, the fetch callback, source management) and eight of the
  fetcher (against a local HTTPS server: the bytes and progress, basic auth, 404/403/401, timeout, cancel, an untrusted certificate; and
  a real refresh of CrossWire's source, an install of KJV and a read of John 3 from it).
- Done: arm64-v8a and x86_64. Both export the same 150 symbols (no CLucene), have 16 KB-aligned segments (Play requires it on newer
  targets) and are about 2.9 MB stripped (29 MB with debug info). x86_64 is built and checked, not run: the emulator here is arm64.
- Done: `Tools/package_android_aar.sh <version>` builds both ABIs, strips them, and publishes `sword` and `sword-okhttp` as AARs to a
  Maven folder (3 MB for the core with both ABIs, the licence and notice inside, consumer keep rules, a sources jar), with the unstripped
  libraries in a symbols zip for `ndk-stack`. A minifying (R8) release app built from the two AARs alone ran a real refresh. The release
  workflow's `android` job runs the script after the iOS release and attaches the results to it (not yet run on GitHub).
- Using the AAR: add the Maven folder as a repository, depend on `org.logoshub:sword-okhttp:<version>` (it brings `sword`), register
  `SwordInstallManager.setHttpFetcher(OkHttpFetcher())` once, and add `packaging { jniLibs { pickFirsts += "**/libc++_shared.so" } }`
  if another library also carries the C++ runtime. The app's manifest gets the INTERNET permission from `sword-okhttp`.
- Not yet: armeabi-v7a (optional, owner's call); Skip's Kotlin calling these classes; `swx_*` in CrossWire's flat API; publishing to a
  Maven repository (GitHub Packages or Maven Central) instead of a release asset.

## Candidates to give CrossWire
1. A pluggable HTTP transport for `InstallMgr` (host fetch callback) in the flat API: removes the curl dependency for any embedding app.
   The most valuable one.
2. A chapter read in one call, and all dictionary keys in one call (less JNI crossing per verse).
3. Versification lists and book names in the flat API.
4. Indexed search where CLucene is built (`swx_create_search_index`).
5. A JNI binding over the flat API (ours, `sword_jni.cpp`), as an alternative to `swordstub.cpp`.
