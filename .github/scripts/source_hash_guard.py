#!/usr/bin/env python3
"""source-hash guard: a Source whose url moves to a new version needs a new sha256 (gominimal/pkgs#1003).

Sources are fetched BY HASH. When a build needs a Source, the store is asked
for its sha256 first, and the url is only downloaded on a miss. So a change
that moves a url to a new release but keeps the old sha256 does not fail: the
old bytes are already in the store under that hash, the build gets them, and
the package silently rebuilds the OLD release under the new version. In
pkgs#1003 the chromium-headless-shell-bin bump moved chromedriver-bin's urls
(they interpolate the browser's `upstream_version`) while chromedriver-bin's
build.ncl, and so its two sha256s, were not touched. chromedriver-bin "built"
in 3 seconds with no download and shipped a 155 driver next to a 156 browser.
Only its `matches_browser` smoke test noticed.

This guard compares the EVALUATED catalog before and after the change (`mip
dump`, both arches), so a url that moves through Nickel interpolation, in a
build.ncl the change never touched, is caught the same as an edited literal.
For each package present on both sides it pairs Sources by sha256 and by url:

  1. stale-sha256 (ERROR)  A Source's url changed and its sha256 did not, and
                           the url's version changed with it: the set of
                           version tokens in the url differs (155.0.8059.84
                           -> 156.0.8078.47, v1.2 -> v2.1, one commit hash
                           -> another). That is the pkgs#1003 shape. A url whose
                           digits are all unchanged is a RELOCATION (a mirror
                           move to gs://minimal-staging-archives, a renamed
                           GitHub org) of the same bytes: reported as a note
                           and allowed, since keeping the sha256 is exactly
                           right there.
  2. stale-url (ERROR)     A Source's sha256 changed, its url did not, the url
                           names a version (a dotted number, a 7+ character
                           hex or digit run such as a commit or sqlite's
                           3530300, or the package's `upstream_version`), and
                           the package's `upstream_version` changed too: the
                           version and hash were bumped and the url was left
                           behind. pkgs#402 did this to sqlite; it cannot
                           build the wrong bytes (the old archive fails the
                           new hash), but it broke every sqlite build on main
                           for 12 days until pkgs#511.
  3. reroll (WARNING)      The same, but the version did not change (or the
                           package has no `upstream_version`): the same
                           release now has different bytes. A warning, not an
                           error, because it cannot build the wrong thing
                           silently: the new hash is not in the store, so the
                           url is downloaded and checked against it, and a
                           mismatch fails the build loudly. What it does need
                           is a reviewer's eye, since the honest reasons (a
                           wrong sha256 corrected, a GitHub archive
                           regenerated) look the same as an upstream that
                           replaced a published release. Blocking on it would
                           mostly teach people to reach for the opt-out. A url
                           with no version in it (a `latest` link) is expected
                           to change bytes; that is only a note.

Opt-out, for the two genuine cases: the sha256 was already right and the
change CORRECTS a url that had been left behind (pkgs#511: sqlite's sha256
had been bumped to 3.53.3 while its url still named 3.50.4's archive; the fix
moved the url and rightly kept the hash), or a url changed digits without
changing bytes (a mirror path that embeds a date). Check the bytes at the new
url hash to the kept sha256, then ADD a line naming it and a reason anywhere
in the change, normally as a comment beside the Source:

    # source-hash-guard: allow <sha256> <reason>

Only lines the change adds count, so a marker left behind in a recipe cannot
excuse a later stale sha256. A marker also silences a reroll warning for the
NEW sha256 it names, and a stale-url error for one.

Input: pairs of `mip dump -p --format json --arch <arch>` outputs, base then
head, one pair per arch, and the change's unified diff (for opt-out markers).

Exit codes: 0 = PASS (warnings and notes allowed), 1 = a stale sha256 or url,
2 = UNVERIFIED (a missing, empty or unparseable dump). 2 is deliberately
non-zero: a guard that cannot see the catalog must not report success.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

MARKER = re.compile(r"source-hash-guard:\s*allow\s+([0-9a-f]{64})\s+(\S.*)")
# A version-like token: a digit run, with any dots/underscores joining runs
# (155.0.8059.84, 1_86_0). Whole tokens, so 1.2 -> 2.1 is a change; a set, so
# a version that appears twice in one url and once in its mirror is not.
VERSION_TOKEN = re.compile(r"\d+(?:[._]\d+)*")
VERSIONISH = re.compile(r"\d+\.\d+|[0-9a-f]{7,}")


def load(path: str) -> dict[str, dict]:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict):  # tolerate a {name: spec} shape
        data = [dict(v, name=k) for k, v in data.items()]
    if not isinstance(data, list) or not data:
        raise ValueError(f"{path}: expected a non-empty list of packages")
    return {p.get("name"): p for p in data}


def sources(pkg: dict) -> list[tuple[str, str]]:
    """(url, sha256) of every Source the package builds from."""
    out = []
    for dep in pkg.get("build_deps") or []:
        if dep.get("type") != "source":
            continue
        src = dep.get("from") or {}
        if src.get("url") and src.get("sha256"):
            out.append((src["url"], src["sha256"].lower()))
    return out


def upstream_version(pkg: dict) -> str | None:
    v = ((pkg.get("attrs") or {}).get("upstream_version") or {}).get("value")
    return v if isinstance(v, str) and v else None


def version_moved(old: str, new: str) -> bool:
    return set(VERSION_TOKEN.findall(old)) != set(VERSION_TOKEN.findall(new))


def is_versioned(url: str, version: str | None) -> bool:
    return bool(VERSIONISH.search(url.lower())) or bool(version and version in url)


def allowed_from_diff(diff: str) -> dict[str, str]:
    """sha256 -> reason, for every opt-out marker on a line the diff ADDS."""
    allowed = {}
    for line in diff.splitlines():
        if line.startswith("+") and not line.startswith("+++"):
            m = MARKER.search(line)
            if m:
                allowed[m.group(1)] = m.group(2).strip()
    return allowed


def compare(base: dict, head: dict) -> list[tuple[str, str, str]]:
    """(level, sha256, message) findings for one package; level is error|warning|note.

    The sha256 is the one an opt-out marker must name: the kept hash for a
    stale-sha256, the new hash for a stale-url or a reroll.
    """
    old, new = sources(base), sources(head)
    old_set = set(old)
    urls_by_sha: dict[str, list[str]] = {}
    shas_by_url: dict[str, list[str]] = {}
    for url, sha in old:
        urls_by_sha.setdefault(sha, []).append(url)
        shas_by_url.setdefault(url, []).append(sha)
    found = []
    for url, sha in new:
        if (url, sha) in old_set:
            continue
        if sha in urls_by_sha:
            was = urls_by_sha[sha]
            if all(version_moved(u, url) for u in was):
                found.append(("error", sha, f"stale-sha256: url changed {was[0]} -> {url} but sha256 stayed {sha}; "
                              "the store will serve the OLD bytes under that hash"))
            else:
                found.append(("note", sha, f"relocated: {was[0]} -> {url} keeps sha256 {sha} (url version tokens unchanged)"))
        elif url in shas_by_url:
            was = shas_by_url[url][0]
            old_v, new_v = upstream_version(base), upstream_version(head)
            if not is_versioned(url, old_v) and not is_versioned(url, new_v):
                found.append(("note", sha, f"unversioned url {url} changed sha256 {was} -> {sha}"))
            elif old_v and new_v and old_v != new_v:
                found.append(("error", sha, f"stale-url: upstream_version moved {old_v} -> {new_v} and sha256 "
                              f"changed {was} -> {sha}, but the url stayed {url}; the build will download the "
                              "old release and fail its hash check"))
            else:
                found.append(("warning", sha, f"reroll: sha256 changed {was} -> {sha} but url stayed {url}; "
                              "the same release now has different bytes, check why"))
    return found


def check(pairs: list[tuple[str, dict, dict]], allowed: dict[str, str]) -> list[tuple[str, str, str, str]]:
    """(level, arch, package, message) across every arch pair, opt-outs applied."""
    out = []
    for arch, base, head in pairs:
        for name in sorted(set(base) & set(head)):
            for level, sha, msg in compare(base[name], head[name]):
                if level in ("error", "warning") and sha in allowed:
                    level, msg = "note", f"{msg} (allowed: {allowed[sha]})"
                out.append((level, arch, name, msg))
    return out


def run(pair_paths: list[tuple[str, str]], diff_path: str | None) -> int:
    pairs = []
    for base_path, head_path in pair_paths:
        arch = os.path.basename(head_path)
        try:
            pairs.append((arch, load(base_path), load(head_path)))
        except (OSError, ValueError) as e:
            print(f"UNVERIFIED {arch}: {e}")
            return 2
    diff = ""
    if diff_path:
        try:
            with open(diff_path, encoding="utf-8", errors="replace") as f:
                diff = f.read()
        except OSError as e:
            print(f"UNVERIFIED diff: {e}")
            return 2
    findings = check(pairs, allowed_from_diff(diff))
    errors = 0
    lines = []
    for level, arch, name, msg in findings:
        tag = {"error": "::error title=source-hash-guard::", "warning": "::warning title=source-hash-guard::"}.get(level, "")
        print(f"{tag}{level.upper()} {arch} {name}: {msg}")
        lines.append(f"- **{level}** `{name}` ({arch}): {msg}")
        errors += level == "error"
    for arch, base, head in pairs:
        print(f"checked {len(set(base) & set(head))} packages present on both sides in {arch}")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("## source-hash guard\n\n" + ("\n".join(lines) if lines else "No Source url/sha256 drift.") + "\n")
    if errors:
        print(f"{errors} error(s). For a stale-sha256, re-pin the Source to the bytes at its new url; if the "
              "kept sha256 really is the hash of the new url's bytes (a url corrected to match it, pkgs#511), "
              "add `# source-hash-guard: allow <sha256> <reason>` in this change. For a stale-url, move the url "
              "to the new release.")
        return 1
    print("PASS")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--pair", nargs=2, action="append", required=True, metavar=("BASE", "HEAD"),
                    help="base and head dump for one arch; repeat per arch")
    ap.add_argument("--diff", help="unified diff of the change (for opt-out markers)")
    args = ap.parse_args()
    return run([tuple(p) for p in args.pair], args.diff)


if __name__ == "__main__":
    sys.exit(main())
