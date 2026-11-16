# Repository Third-Party Licensing

This inventory covers the entire source repository, including unused contributor
code. The [binary distribution notices](docs/distribution/THIRD_PARTY_LICENSES.txt)
have a narrower scope and are copied to `dist/THIRD_PARTY_LICENSES.txt` when
packaging. Neither document is a blanket license grant or legal clearance.

The top-level [LICENSE](LICENSE) remains the unchanged Apache License 2.0 text.
Preserve each file's original notices. Files explicitly offering Apache 2.0 or
LGPL retain that offer; this binary build selects Apache where offered. Do not
assume that independently bundled code inherits those choices.

## Component Inventory

| Source area | Evidence and terms | In the default library? |
| --- | --- | --- |
| Core and shared CLucene | Apache 2.0 or LGPL notices in individual files, with third-party exceptions below | Yes |
| Contributor highlighter | Apache 2.0 source notices | No; optional |
| Contributor analysis | Mostly CLucene Apache-or-LGPL notices; PorterStemmer is a separate unresolved case | No |
| Contributor utilities | CLucene Apache-or-LGPL notices; linked zlib is separate | No |
| Snowball C++ wrapper | CLucene Apache-or-LGPL notices | No |
| Snowball C stemmer engine | Upstream BSD-3-Clause; reconcile bundled snapshot with upstream | No |
| MD5 implementation | Gary McNickle/RSA permission and identification terms, in addition to CLucene notices | Yes |
| GLib-derived classification and UTF-8 code | Explicit additional Apache permission in source notices | Yes |
| Unicode 4.0 character data | Historical UCD Terms of Use located; exact table derivation still to verify | Yes |
| Preserved bundled deflate implementation | zlib terms; excluded incomplete source, not SDK zlib | No |

The generated Unicode table identifies version 4.0. This does not establish the
exact generator/input match. Contributor PorterStemmer has attribution but no
clear permission grant in this checkout; resolve its provenance before relying
on a license for it. An upstream license snapshot is evidence, not permission
to change existing notices or assume exceptions do not apply.

## Module-Local Records

- [Snowball](src/contribs/CLucene/snowball/LICENSING.md): saved upstream BSD text,
	wrapper license, and snapshot-reconciliation status.
- [Contributor analysis](src/contribs/CLucene/analysis/LICENSING.md): inherited
	CLucene terms and the unresolved PorterStemmer permission grant.
- [Highlighter](src/contribs/CLucene/highlighter/LICENSING.md) and
	[contributor utilities](src/contribs/CLucene/util/LICENSING.md): local Apache
	text with explicit scope and retained source notices.
- [MD5](src/core/CLucene/util/LICENSE-MD5.txt): complete implementation notice.
- [Unicode/GLib](src/shared/CLucene/config/LICENSING.md): historical Unicode 4.0
	terms, original GLib-derived notices, and table-provenance limitation.
- [Preserved deflate](src/shared/CLucene/util/LICENSING.md): zlib 1.2.3 terms
	rather than an unqualified copy of today's zlib license.

These records preserve the applicable historical evidence; "up to date" refers
to the record, not relicensing old code under whichever terms appear online now.

## Authoritative References

- [Historical Unicode 4.0 UCD Terms of Use](https://www.unicode.org/Public/4.0-Update/UCD-4.0.0.html)
- [Current Unicode licensing](https://www.unicode.org/copyright.html)
- [Snowball licensing](https://snowballstem.org/license.html)
- [zlib licensing](https://www.zlib.net/zlib_license.html)

Keep complete permission notices with the relevant source, not only these links.
Repository licensing includes unused code because publishing it distributes
source. Binary releases need notices for their included code and headers. SDK
runtime redistribution is the consuming application's separate responsibility.