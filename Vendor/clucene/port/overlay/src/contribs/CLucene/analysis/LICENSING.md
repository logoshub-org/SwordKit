# Contributor Analysis Licensing Record

Recorded 2026-10-12 from this checkout's source headers. Most files, including
LanguageBasedAnalyzer and the CJK/German contributors, offer Apache License 2.0
or LGPL. [LICENSE-APACHE-2.0.txt](LICENSE-APACHE-2.0.txt) supplies the Apache text
for files explicitly offering that option; it is not a blanket license for the
directory. Keep the original copyright notices and dual-license offers.

## PorterStemmer: Permission Unresolved

[PorterStemmer.cpp](PorterStemmer.cpp) and [PorterStemmer.h](PorterStemmer.h)
attribute the original algorithm to Martin Porter and modifications to Hemant
Muthiyan, but do not provide a clear permission grant. Do not assume the adjacent
Apache license or Snowball's BSD license applies to this modified implementation.

Investigate its exact upstream implementation, CLucene's original distribution,
and the modifier's permission record. The headers reference
http://www.tartarus.org/~martin/PorterStemmer. Preserve their attribution while
the permission question remains unresolved. This record is not a license grant.

These contributor implementations are not included in the current binary build.