# Snowball Licensing Record

Recorded 2026-10-12. This folder contains two layers with different notices:

- The C++ CLucene wrapper files offer Apache 2.0 or LGPL in their source headers.
  [LICENSE-APACHE-2.0.txt](LICENSE-APACHE-2.0.txt) supplies the Apache text; it does
  not relicense the C engine.
- The upstream Snowball/libstemmer engine uses BSD-3-Clause except where noted.
  [LICENSE-SNOWBALL.txt](LICENSE-SNOWBALL.txt) reproduces the complete permission
  text retrieved from [the official license page](https://snowballstem.org/license.html).

[snowball.version](snowball.version) identifies only "May 2005". Reconcile this
bundled snapshot and any file-specific exceptions with that upstream record
before claiming a complete provenance audit. The saved license is a dated
upstream record, not proof of an exact source-version match.

Snowball is preserved in the repository but not included in the current library
build. Preserve original notices and include the BSD notice if distributing the
engine in source or binary form.