# Patches to CLucene 2.3.3.4

Applied in name order to the pristine upstream tree (`Tools/assemble_clucene.sh`). Paths are relative to the assembled tree
(`src/core`, `src/shared`, `src/contribs`; upstream's `contribs-lib` becomes `contribs`).

| Patch | What | Why |
|---|---|---|
| 01-android-guards | `__ANDROID__` branches: a `float_t` typedef, log calls in `IndexWriter.cpp` (with a brace reformat of one `if`), `wcrtomb`, config and equator tweaks | The Android build (untested here). iOS ignores them. |
| 02-modern-compiler | `-1LL` and `(-2147483647 - 1)` for out-of-range integer constants, `NULL` to `0` for ints, `#include <pthread.h>` and `<dirent.h>` | Upstream does not compile cleanly with current Clang. |
| 03-behaviour | `DEFAULT_MAX_FIELD_LENGTH` 10 000 to 1 000 000; `Payload` no longer `assert(false)`; `ConstantScoreQuery` deletes its filter bits only if the filter says so (`shouldDeleteBitSet`); a `BYTE_OFFSETS` table in `BitSet` | Changes what the library does, so kept apart. Upstream hit the field-length bound indexing large modules. SWORD sets its own limit (`setMaxFieldLength`), so the first change matters only to other users. |
| 05-android-build-fixes | The thread-id `toString` overload is left out on Android (`pthread_t` is a `long`, so it redeclares the `int64_t` one); an explicit `(TCHAR)` cast where an `int` narrows to `wchar_t` | Found by building for Android (NDK 30.0.16248370, arm64-v8a). iOS ignores them. The port's config templates carry two more Android guards (no `<sys/timeb.h>`; bionic declares `stat64` itself). |
| 04-cosmetic | A blank line, whitespace in `error.cpp`, commented-out debug `printf`s and an unused variable in the highlighter, and the typo `CRITICAL_SECTIONsdsds` in the Windows-only branch of `_threads.h` | Carried over unchanged from the rework so the binary stays the one that was tested. The typo should be fixed or dropped if Windows is ever built. |

`excluded-upstream-files.txt` lists the upstream build-system files and directories (autotools-era CMake, `.pc` and config templates)
that `port/` replaces; they stay in `upstream/` and are left out of the assembled tree.

Licence audit notes (`LICENSING.md` and the licence texts for bundled code) are in `port/overlay/`, placed at their `src/` paths.
