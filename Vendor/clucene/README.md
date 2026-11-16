# Vendor/clucene

- `upstream/`: pristine CLucene 2.3.3.4 (SourceForge tag `clucene-src-2.3.3.4`, a834f87). Never edited.
- `patches/`: our changes to it (see `patches/README.md`).
- `port/`: the CMake build, presets, scripts and headers for iOS and Android, and the licence notes (`overlay/`).

`Tools/assemble_clucene.sh <dir>` builds the tree that is compiled; `Tools/build_clucene_xcframework.sh` does that and builds the xcframework. Origin and licence: `../UPSTREAM-clucene.txt`, `port/NOTICE`, the root `NOTICE`.
