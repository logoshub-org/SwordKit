#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Logos Hub Ltd
#
# The GitLab Releases API calls the GitLab pipeline (.gitlab-ci.yml) makes. GitLab releases hold links, not files: the files go to the
# project's generic package registry and the release links to them.
#
#   Tools/gitlab_release.py exists <tag>                                   exit 0 if the release exists, 1 if not
#   Tools/gitlab_release.py create <tag> <title> <description> [name=url ...]   create the release (the tag must exist)
#   Tools/gitlab_release.py link <tag> name=url [name=url ...]             add links, replacing any of the same name (safe to re-run)
#
# Needs CI_API_V4_URL and CI_PROJECT_ID (GitLab sets them) and RELEASE_TOKEN (a project access token with the api scope).
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "%s/projects/%s" % (os.environ["CI_API_V4_URL"], os.environ["CI_PROJECT_ID"])
TOKEN = os.environ["RELEASE_TOKEN"]


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method,
                                 headers={"PRIVATE-TOKEN": TOKEN, "Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        text = r.read()
        return json.loads(text) if text else None


def links(args):
    out = []
    for a in args:
        name, sep, url = a.partition("=")
        if not sep or not name or not url.startswith("https://"):
            sys.exit("a link is name=https://...: %r" % a)
        out.append({"name": name, "url": url, "link_type": "package"})
    return out


def tag_path(tag):
    return "/releases/" + urllib.parse.quote(tag, safe="")


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: gitlab_release.py exists|create|link <tag> ... (see the comment at the top)")
    cmd, tag, rest = sys.argv[1], sys.argv[2], sys.argv[3:]
    if cmd == "exists":
        try:
            call("GET", tag_path(tag))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                sys.exit(1)
            raise
        return
    if cmd == "create":
        if len(rest) < 2:
            sys.exit("create <tag> <title> <description> [name=url ...]")
        call("POST", "/releases", {"tag_name": tag, "name": rest[0], "description": rest[1],
                                   "assets": {"links": links(rest[2:])}})
        return
    if cmd == "link":
        new = links(rest)
        names = {l["name"] for l in new}
        for old in call("GET", tag_path(tag) + "/assets/links"):
            if old["name"] in names:
                call("DELETE", "%s/assets/links/%d" % (tag_path(tag), old["id"]))
        for l in new:
            call("POST", tag_path(tag) + "/assets/links", l)
        return
    sys.exit("unknown command %r" % cmd)


main()
