# Repository Third-Party Licensing

This inventory covers the entire source repository, including unused contributor
code. The [binary distribution notices](docs/distribution/THIRD_PARTY_LICENSES.txt)
have a narrower scope and are copied to `dist/THIRD_PARTY_LICENSES.txt` when
packaging. Neither document is a blanket license grant or legal clearance.

The top-level [LICENSE](LICENSE) remains the unchanged Apache License 2.0 text
(it covers this port's own files). Preserve each file's original notices. Files
explicitly offering Apache 2.0 or LGPL retain that offer. SwordKit, which builds
and ships this library, uses CLucene under the GNU Lesser General Public License,
version 2.1, the option that is compatible with GPL-2.0-only (owner's decision,
2026-11-16; the LGPL text is `Vendor/clucene/upstream/LGPL.license` in SwordKit).
It does not select the Apache option. Do not assume that independently bundled
code inherits that choice.

## Component Inventory

| Source area | Evidence and terms | In the default library? |
| --- | --- | --- |
| Core and shared CLucene | Apache 2.0 or LGPL notices in individual files, with third-party exceptions below | Yes |
| Contributor highlighter | Apache 2.0 source notices | No; optional |
| Contributor analysis | Mostly CLucene Apache-or-LGPL notices; not included in the binary | No |
| Contributor utilities | CLucene Apache-or-LGPL notices; linked zlib is separate | No |
| Snowball C++ wrapper | CLucene Apache-or-LGPL notices | No |
| Snowball C stemmer engine | Upstream BSD-3-Clause; not included in the binary | No |
| MD5 implementation | Gary McNickle/RSA permission and identification terms, in addition to CLucene notices | Yes |
| GLib-derived classification and UTF-8 code | LGPL 2 or later notice, and explicit additional Apache permission, in source notices; used under LGPL-2.1 | Yes |
| Unicode 4.0 character data | Used under the Unicode 4.0.0 UCD Terms of Use | Yes |
| Preserved bundled deflate implementation | zlib terms; excluded incomplete source, not SDK zlib | No |

The generated Unicode table identifies version 4.0 and is used under the Unicode
4.0.0 UCD Terms of Use. Contributor PorterStemmer is not included in the default
library, so its terms do not apply to the distributed binary.

## Module-Local Records

- [Snowball](src/contribs/CLucene/snowball/LICENSING.md): saved upstream BSD text,
	wrapper license, and snapshot-reconciliation status.
- [Contributor analysis](src/contribs/CLucene/analysis/LICENSING.md): inherited
	CLucene terms; PorterStemmer is not included in the default library.
- [Highlighter](src/contribs/CLucene/highlighter/LICENSING.md) and
	[contributor utilities](src/contribs/CLucene/util/LICENSING.md): local Apache
	text with explicit scope and retained source notices.
- [MD5](src/core/CLucene/util/LICENSE-MD5.txt): complete implementation notice.
- [Unicode/GLib](src/shared/CLucene/config/LICENSING.md): historical Unicode 4.0
	terms and original GLib-derived notices.
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