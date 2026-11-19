#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Logos Hub Ltd
#
# Writes a release's download URLs and checksums into Package.swift (the release workflow runs this; run it by hand to test).
#
#   Tools/update_manifest.py --repo owner/SwordKit --version 1.0.0 --swordcore-checksum <hex> \
#       --clucene-tag clucene-2.3.3.4 --clucene-checksum <hex> [--package Package.swift]
#
# With --swordcore-url and --clucene-url it writes those URLs instead of the GitHub release ones (the GitLab pipeline passes its
# package-registry URLs), and --repo is not needed.
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
    ap.add_argument("--repo", help="owner/name on GitHub (not needed with both URLs)")
    ap.add_argument("--version", required=True, help="SwordKit version, e.g. 1.0.0")
    ap.add_argument("--swordcore-checksum", required=True)
    ap.add_argument("--clucene-tag", default="clucene-2.3.3.4")
    ap.add_argument("--clucene-checksum", required=True)
    ap.add_argument("--package", default="Package.swift")
    ap.add_argument("--swordcore-url", help="SwordCore.xcframework.zip's download URL (default: the GitHub release's)")
    ap.add_argument("--clucene-url", help="CLucene.xcframework.zip's download URL (default: the GitHub release's)")
    a = ap.parse_args()
    if not (a.swordcore_url and a.clucene_url) and not (a.repo and re.match(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", a.repo)):
        sys.exit("--repo must be owner/name (or pass both --swordcore-url and --clucene-url)")
    for u in (a.swordcore_url, a.clucene_url):
        if u is not None and not re.match(r"^https://[^\s\"]+$", u):
            sys.exit("a URL must be https:// with no spaces or quotes")
    if not re.match(r"^[0-9]+\.[0-9]+\.[0-9]+$", a.version):
        sys.exit("--version must be like 1.0.0")
    for c in (a.swordcore_checksum, a.clucene_checksum):
        if not HEX.match(c):
            sys.exit("a checksum must be 64 lowercase hex digits")
    text = open(a.package).read()
    base = "https://github.com/%s/releases/download" % a.repo
    text = rewrite(text, "SwordCore", "SwordCore.xcframework.zip",
                   a.swordcore_url or "%s/%s/SwordCore.xcframework.zip" % (base, a.version), a.swordcore_checksum)
    text = rewrite(text, "CLucene", "CLucene.xcframework.zip",
                   a.clucene_url or "%s/%s/CLucene.xcframework.zip" % (base, a.clucene_tag), a.clucene_checksum)
    open(a.package, "w").write(text)


main()
