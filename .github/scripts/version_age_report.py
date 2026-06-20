#!/usr/bin/env python3
"""Report-only upstream version-age check (gominimal/inbox#21, criterion #20).

For each changed package, resolve the upstream release date and compare its age
to a reference minimum (default 7 days). Output is a Markdown table appended to
$GITHUB_STEP_SUMMARY. This script NEVER exits non-zero for a policy reason
(too-fresh / unknown date) — it only reports. It exits non-zero solely on a
programming error, which the workflow downgrades to a warning.

Date resolution precedence, per package:
  1. attrs.released_at            -- explicit maintainer declaration (override)
  2. GithubRepo  -> GitHub API    -- releases-by-tag, else tag's commit date
  3. GnuProject  -> ftp.gnu.org   -- Last-Modified of the release tarball
  4. any source  -> source-URL    -- HEAD the package's own source for its
                                     Last-Modified ("date on the file"); catches
                                     no-provenance packages + tiers 2/3 misses
  5. otherwise   -> UNKNOWN       -- "needs attrs.released_at" (non-http source)

Tier 4 shrinks the UNKNOWN set: most no-provenance packages (toolchains, X11
libs, pinned binaries) still have an http(s) source tarball whose Last-Modified
is a usable availability date. The genuine residue is sources with no http(s)
date (gs:// mirrors, git), which still need attrs.released_at. (Note: Last-
Modified is the artifact's availability/upload time, not strictly the upstream
release date -- close enough for a soak gate, and dwell backstops it.)

SECURITY: `name`/`owner`/`repo`/`version` come from untrusted build.ncl. They are
validated against a strict charset before being composed into any URL or passed
to `gh`/`curl`, so a hostile `upstream_version` cannot redirect egress (SSRF).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime


# ---- SSRF guard: identifiers that get composed into URLs / passed to gh/curl --
# Reject anything outside this charset (no '@', '/', ':', whitespace, etc.), which
# blocks curl userinfo host-flips like version="4.9@evil.com/x". A legit version
# that fails this (rare) degrades safely to UNKNOWN -- this is report-only.
_SAFE_TOKEN = re.compile(r"^[A-Za-z0-9._+-]+$")


def safe_token(s: str | None) -> bool:
    return bool(s) and bool(_SAFE_TOKEN.match(s))


# ---- minimal-dump attr extraction ------------------------------------------
# Shapes come from crates/minimal/src/cmd_dump.rs (PkgAttr serde):
#   String attr  -> {"value": "...", "pos": [..]}        (untagged)
#   Map attr     -> {"type":"map","value": {field: PkgAttr, ...}}
#   Enum variant -> {"type":"enum_variant","value": ["GithubRepo", <inner>]}
#   Source dep   -> {"type":"source","url":"...","sha256":"...", ...}

def attr_str(attrs: dict, key: str) -> str | None:
    a = attrs.get(key)
    if isinstance(a, dict) and isinstance(a.get("value"), str):
        return a["value"]
    return None


def provenance(attrs: dict) -> dict | None:
    sp = attrs.get("source_provenance")
    if not isinstance(sp, dict):
        return None
    spv = sp.get("value") if sp.get("type") == "map" else sp
    if not isinstance(spv, dict):
        return None

    cat = spv.get("category")
    category = None
    if isinstance(cat, dict):
        cv = cat.get("value")
        if isinstance(cv, list) and cv:
            category = cv[0]
        elif isinstance(cv, str):
            category = cv
    elif isinstance(cat, str):
        category = cat

    def field(k: str) -> str | None:
        e = spv.get(k)
        return e["value"] if isinstance(e, dict) and isinstance(e.get("value"), str) else None

    return {"category": category, "owner": field("owner"),
            "repo": field("repo"), "name": field("name")}


def source_ext(pkg: dict) -> str | None:
    for d in pkg.get("build_deps", []):
        if isinstance(d, dict) and d.get("type") == "source":
            m = re.search(r"\.tar\.([A-Za-z0-9]+)$", d.get("url", ""))
            if m:
                return m.group(1)
    return None


def source_url(pkg: dict) -> str | None:
    """The package's primary source URL (first `source` dep carrying a url).

    A source dep carries its fetch spec under `from` (a dict shaped like
    {"type": "web", "url": ..., "sha256": ...}); tolerate an older flat shape
    where `url` sits directly on the dep. NOTE: most catalog sources resolve to
    a `gs://minimal-staging-archives/...` mirror, which has no HTTP Last-Modified
    oracle -- only the http(s) sources (a minority) yield a date via this tier.
    """
    for d in pkg.get("build_deps", []):
        if not (isinstance(d, dict) and d.get("type") == "source"):
            continue
        frm = d.get("from")
        if isinstance(frm, dict) and frm.get("url"):
            return frm["url"]
        if d.get("url"):
            return d["url"]
    return None


# ---- GitHub date resolution ------------------------------------------------

def candidate_tags(version: str, repo: str) -> list[str]:
    """Bounded, ordered tag guesses covering observed formats: bare
    (ripgrep 15.1.0), v-prefixed (bat v0.26.1), name-prefixed + dots->underscores
    (curl curl-8_20_0)."""
    vu = version.replace(".", "_")
    cands = [version, f"v{version}", f"{repo}-{version}", f"{repo}-{vu}",
             f"{repo}_{version}", f"{repo}_{vu}", vu, f"v{vu}"]
    seen, out = set(), []
    for c in cands:
        if c not in seen:
            seen.add(c)
            out.append(c)
    return out


def gh_json(path: str) -> dict | None:
    p = subprocess.run(["gh", "api", path], capture_output=True, text=True)
    if p.returncode != 0:
        return None
    try:
        return json.loads(p.stdout)
    except json.JSONDecodeError:
        return None


def github_date(owner: str, repo: str, version: str) -> tuple[str | None, str]:
    # 1) formal releases (gives published_at). Prefer published_at over
    #    created_at: created_at is the underlying commit, which can predate the
    #    actual release by months on long-lived branches.
    for t in candidate_tags(version, repo):
        rel = gh_json(f"repos/{owner}/{repo}/releases/tags/{t}")
        if rel and (rel.get("published_at") or rel.get("created_at")):
            d = (rel.get("published_at") or rel["created_at"])[:10]
            return d, f"github release (tag {t})"
    # 2) tags-only repos: resolve the tag to a commit/annotated-tag date.
    for t in candidate_tags(version, repo):
        # Singular `git/ref/...` returns one object; the plural `git/refs/...`
        # returns a LIST of all prefix-matching refs (which broke `.get`). Guard
        # against a list anyway and accept only an exact `refs/tags/{t}` match.
        ref = gh_json(f"repos/{owner}/{repo}/git/ref/tags/{t}")
        if not ref:
            continue
        if isinstance(ref, list):
            ref = next((r for r in ref if isinstance(r, dict)
                        and r.get("ref") == f"refs/tags/{t}"), None)
            if not ref:
                continue
        obj = ref.get("object", {})
        sha, kind = obj.get("sha"), obj.get("type")
        if kind == "tag":  # annotated
            tag = gh_json(f"repos/{owner}/{repo}/git/tags/{sha}")
            d = (tag or {}).get("tagger", {}).get("date")
            if d:
                return d[:10], f"github annotated tag {t}"
        elif kind == "commit":  # lightweight
            c = gh_json(f"repos/{owner}/{repo}/commits/{sha}")
            d = (((c or {}).get("commit") or {}).get("committer") or {}).get("date")
            if d:
                return d[:10], f"github tag commit {t}"
    return None, f"no github release/tag matched {version}"


# ---- GNU date resolution ---------------------------------------------------

def gnu_date(name: str, version: str, ext: str | None) -> tuple[str | None, str]:
    exts = [ext] if ext else []
    for e in ("xz", "gz", "bz2", "lz"):
        if e not in exts:
            exts.append(e)
    for e in exts:
        url = f"https://ftp.gnu.org/gnu/{name}/{name}-{version}.tar.{e}"
        p = subprocess.run(["curl", "-sI", "--max-time", "20", url],
                           capture_output=True, text=True)
        if p.returncode != 0 or not p.stdout:
            continue
        status_ok = " 200" in p.stdout.splitlines()[0]
        last_mod = next((ln.split(":", 1)[1].strip()
                         for ln in p.stdout.splitlines()
                         if ln.lower().startswith("last-modified:")), None)
        if status_ok and last_mod:
            try:
                dt = parsedate_to_datetime(last_mod).astimezone(timezone.utc)
                return dt.date().isoformat(), f"ftp.gnu.org (.tar.{e})"
            except (TypeError, ValueError):
                pass
    return None, "ftp.gnu.org HEAD failed"


# ---- generic source-URL date (the "date on the file" fallback) -------------

def url_last_modified(url: str) -> tuple[str | None, str]:
    """HEAD the package's own source URL and read its Last-Modified date.

    The URL is taken WHOLE from the spec (the exact one the sandboxed build
    fetches), not composed from identifiers, so there's no SSRF-via-version risk
    here; restricted to http(s) and follows redirects (release assets often 30x
    to a CDN). NOTE: on a fork PR the URL is attacker-influenceable, but this is
    a read-only HEAD on an ephemeral runner with no secrets, fetching the same
    URL the build already does -- if that surface is unwanted, gate this tier to
    same-repo PRs (reviewer's call).

    Last-Modified is the artifact's availability/upload time, not strictly the
    upstream release date -- usually close, and arguably the more correct signal
    for a soak gate. Dwell (git time in main) backstops it, so a package is never
    ungated even when this returns None.
    """
    if not url.lower().startswith(("http://", "https://")):
        return None, "non-http(s) source (no Last-Modified oracle)"
    p = subprocess.run(["curl", "-sIL", "--max-time", "20", url],
                       capture_output=True, text=True)
    if p.returncode != 0 or not p.stdout:
        return None, "source-url HEAD failed"
    # Across redirect hops take the last Last-Modified (the final response's).
    last_mod = None
    for ln in p.stdout.splitlines():
        if ln.lower().startswith("last-modified:"):
            last_mod = ln.split(":", 1)[1].strip()
    if last_mod:
        try:
            dt = parsedate_to_datetime(last_mod).astimezone(timezone.utc)
            return dt.date().isoformat(), "source-url Last-Modified"
        except (TypeError, ValueError):
            pass
    return None, "source-url has no Last-Modified header"


# ---- per-package resolution ------------------------------------------------

def resolve(pkg: dict) -> tuple[str, str | None, str, str]:
    """Return (version, date|None, source_type, date_source_detail)."""
    attrs = pkg.get("attrs", {})
    version = attr_str(attrs, "upstream_version") or "?"
    declared = attr_str(attrs, "released_at")
    prov = provenance(attrs)
    src_type = (prov or {}).get("category") or "no-provenance"

    if declared:
        return version, declared, src_type, "attrs.released_at"

    # Provenance-specific oracles first (most accurate: the real upstream
    # release date). Fall THROUGH to the generic source-URL fallback if they
    # don't resolve (unmatched tag, unsafe identifier), rather than giving up.
    if prov and prov["category"] == "GithubRepo" and prov["owner"] and prov["repo"]:
        if safe_token(prov["owner"]) and safe_token(prov["repo"]) and safe_token(version):
            d, detail = github_date(prov["owner"], prov["repo"], version)
            if d:
                return version, d, src_type, detail
    elif prov and prov["category"] == "GnuProject" and prov["name"]:
        if safe_token(prov["name"]) and safe_token(version):
            d, detail = gnu_date(prov["name"], version, source_ext(pkg))
            if d:
                return version, d, src_type, detail

    # Generic fallback: the source artifact's own Last-Modified ("date on the
    # file"). Catches no-provenance packages AND tier-2/3 misses. This is what
    # shrinks the UNKNOWN set.
    surl = source_url(pkg)
    if surl:
        d, detail = url_last_modified(surl)
        if d:
            return version, d, src_type, detail

    return version, None, src_type, "no derivable date; needs attrs.released_at"


def classify(date_str: str | None, min_age: int) -> tuple[int | None, str]:
    if not date_str:
        return None, "needs released_at"
    try:
        rd = datetime.strptime(date_str, "%Y-%m-%d").replace(tzinfo=timezone.utc).date()
    except ValueError:
        return None, "unparseable date"
    age = (datetime.now(timezone.utc).date() - rd).days
    if age < 0:
        return age, "release date in the future?"
    if age < min_age:
        return age, f"too fresh (<{min_age}d)"
    return age, f"aged >={min_age}d"


# ---- summary emit ----------------------------------------------------------

def emit(markdown: str) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a") as f:
            f.write(markdown)
    else:
        print("\n" + markdown)


# ---- main ------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--packages-file", required=True)
    ap.add_argument("--min-age-days", type=int, default=7)  # britney2-style soak; #20
    args = ap.parse_args()

    # A missing/empty/garbled dump (e.g. the workflow's dump-failed fallback)
    # must produce a one-line note, not a stack trace / red check.
    try:
        with open(args.dump) as f:
            catalog = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        emit("## version-age report (informational, non-blocking)\n\n"
             f"> `minimal dump` output was unavailable ({type(e).__name__}); "
             "skipping the version-age report for this run. Non-blocking.\n")
        return 0
    if not isinstance(catalog, list):
        emit("## version-age report (informational, non-blocking)\n\n"
             "> `minimal dump` returned an unexpected shape; skipping. "
             "Non-blocking.\n")
        return 0

    by_name = {p["name"]: p for p in catalog if isinstance(p, dict) and "name" in p}

    with open(args.packages_file) as f:
        changed = [ln.strip() for ln in f if ln.strip()]

    rows, unknown = [], []
    for name in changed:
        pkg = by_name.get(name)
        if pkg is None:
            rows.append((name, "?", "unresolved", "-", "-",
                         "no such package in catalog (renamed/deleted/dir!=name?)"))
            unknown.append(name)
            continue
        version, date, src_type, detail = resolve(pkg)
        age, verdict = classify(date, args.min_age_days)
        icon = {"aged": "✅", "too": "⏳", "needs": "❓"}.get(
            verdict.split()[0], "⚠️")
        rows.append((name, version, src_type, date or "—",
                     str(age) if age is not None else "—", f"{icon} {verdict}"))
        if date is None:
            unknown.append(name)
        print(f"{name} {version} [{src_type}] -> {date or 'UNKNOWN'} "
              f"({detail}); {verdict}")

    out = ["## version-age report (informational, non-blocking)", "",
           f"Reference minimum age: **{args.min_age_days} days** "
           "(gominimal/inbox#20; Debian britney2 minimum-soak precedent).", "",
           "| package | version | source | release date | age (days) | vs reference |",
           "| --- | --- | --- | --- | ---: | --- |"]
    for r in rows:
        out.append("| " + " | ".join(r) + " |")
    out += ["",
            "> This check never blocks merge and is intentionally excluded from "
            "branch-protection required checks. ⏳ = too fresh to promote "
            "*today*; ❓ = no derivable date."]
    if unknown:
        out += ["", "### ❓ Missing `attrs.released_at`", "",
                "These packages have no GitHub/GNU source to derive a date from "
                "(or an unsafe identifier). Backfill a verified UTC date:", "",
                "```nickel", 'attrs.released_at = "YYYY-MM-DD",', "```", "",
                *[f"- `{n}`" for n in unknown]]

    emit("\n".join(out) + "\n")
    return 0  # report-only: success regardless of verdicts


if __name__ == "__main__":
    sys.exit(main())
