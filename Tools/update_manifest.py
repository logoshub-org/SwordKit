#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Logos Hub Ltd
#
# Writes a release's download URLs and checksums into Package.swift (the release workflow runs this; run it by hand to test).
#
#   Tools/update_manifest.py --repo owner/SwordKit --version 1.0.0 --swordcore-checksum <hex> \
#       --clucene-tag clucene-2.3.3.4 --clucene-checksum <hex> [--package Package.swift]
#
# It is safe to run again: each target's URL and checksum are found by the target's name, whatever they hold now.
import argparse
import re
import sys

HEX = re.compile(r"^[0-9a-f]{64}$")


def rewrite(text, name, zip_name, url, checksum):
    pattern = re.compile(
        r'(\.binaryTarget\(\s*name:\s*"%s",\s*url:\s*)"[^"]*"(,[^\n]*\n\s*checksum:\s*)"[^"]*"' % re.escape(name))
    new, count = pattern.subn(lambda m: '%s"%s"%s"%s"' % (m.group(1), url, m.group(2), checksum), text)
    if count != 1:
        sys.exit("Package.swift: expected one remote binary target named %s, found %d" % (name, count))
    return new


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True, help="owner/name on GitHub")
    ap.add_argument("--version", required=True, help="SwordKit version, e.g. 1.0.0")
    ap.add_argument("--swordcore-checksum", required=True)
    ap.add_argument("--clucene-tag", default="clucene-2.3.3.4")
    ap.add_argument("--clucene-checksum", required=True)
    ap.add_argument("--package", default="Package.swift")
    a = ap.parse_args()
    if not re.match(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", a.repo):
        sys.exit("--repo must be owner/name")
    if not re.match(r"^[0-9]+\.[0-9]+\.[0-9]+$", a.version):
        sys.exit("--version must be like 1.0.0")
    for c in (a.swordcore_checksum, a.clucene_checksum):
        if not HEX.match(c):
            sys.exit("a checksum must be 64 lowercase hex digits")
    text = open(a.package).read()
    base = "https://github.com/%s/releases/download" % a.repo
    text = rewrite(text, "SwordCore", "SwordCore.xcframework.zip",
                   "%s/%s/SwordCore.xcframework.zip" % (base, a.version), a.swordcore_checksum)
    text = rewrite(text, "CLucene", "CLucene.xcframework.zip",
                   "%s/%s/CLucene.xcframework.zip" % (base, a.clucene_tag), a.clucene_checksum)
    open(a.package, "w").write(text)


main()
