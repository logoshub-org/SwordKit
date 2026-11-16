# Shared Utilities Licensing Record

Recorded 2026-10-12. Ordinary CLucene utility files retain their own
Apache-or-LGPL source notices; do not apply those terms to independent code.

[deflate.cpp](deflate.cpp) is an incomplete preserved zlib implementation. Its
copyright string identifies deflate 1.2.3 and its header directs readers to the
missing zlib.h notice. [LICENSE-ZLIB-1.2.3.txt](LICENSE-ZLIB-1.2.3.txt) restores
the permission text from the official upstream v1.2.3 header, including its
original 1995-2005 copyright, with retrieval date and source URL recorded.

This is a version-aligned license reference, not a byte-for-byte verification
of this renamed/ported deflate source against the upstream implementation.
Preserve the bundled notice and mark altered versions appropriately.

The build excludes deflate.cpp and links SDK/NDK zlib instead. Updating the
record does not include this source in the binary or change its license.