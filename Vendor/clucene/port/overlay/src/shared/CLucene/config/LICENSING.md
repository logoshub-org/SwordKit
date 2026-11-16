# Unicode and GLib-Derived Code Licensing Record

Recorded 2026-10-12. This directory has two distinct attribution layers:

- [NOTICE-GLIB.txt](NOTICE-GLIB.txt) reproduces the notices from the GLib-derived
  character-classification and UTF-8 implementations. Their headers explicitly
  offer additional Apache licensing; the full text is
  [LICENSE-APACHE-2.0.txt](LICENSE-APACHE-2.0.txt).
- [LICENSE-UNICODE-4.0.txt](LICENSE-UNICODE-4.0.txt) preserves the historical
  Unicode 4.0 UCD Terms of Use from
  [the official release documentation](https://www.unicode.org/Public/4.0-Update/UCD-4.0.0.html).

[_gunichartables.h](_gunichartables.h) declares Unicode data version 4.0 but
does not identify the exact table generator inputs. Reconcile those inputs with
the original CLucene/GLib source distribution before claiming a completed
provenance audit. Do not replace the historical notice with today's terms on
the assumption that a current web page automatically licenses this snapshot.

The [binary notices](../../../../docs/distribution/THIRD_PARTY_LICENSES.txt)
also preserve the current Unicode license as a clearly labeled additional
reference, not a replacement for these historical terms. The other CLucene
compatibility files retain their own individual source notices.