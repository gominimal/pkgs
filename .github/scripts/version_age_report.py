#!/usr/bin/env python3
"""Report-only upstream version-age check (gominimal/inbox#21, criterion #20).

For each changed package, resolve the upstream release date and compare its age
to a reference minimum (default 7 days). Output is a Markdown table appended to
$GITHUB_STEP_SUMMARY. This script NEVER exits non-zero for a policy reason
(too-fresh / unknown date) — it only reports. It exits non-zero solely on a
programming error, which the workflow downgrades to a warning.

Date resolution precedence, per package:
  1. attrs.released_at            -- explicit maintainer declaration (override)
  2. self-dated version           -- trailing YYYYMMDD in the version (ncurses &
                                     other dated snapshots); pure, no network
  3. GithubRepo  -> GitHub API    -- releases-by-tag, else tag's commit date
  4. GnuProject  -> ftp.gnu.org   -- Last-Modified of the tarball (flat / nested
                                     per-version dir / aliased project dir)
  5. any source  -> source-URL    -- HEAD the package's own https source for its
                                     Last-Modified ("date on the file"); catches
                                     no-provenance packages + tier 3/4 misses
  6. otherwise   -> UNKNOWN       -- "needs attrs.released_at"

A full-catalog census (2026-06-20) put tier coverage at 280/373: most sources
are a `gs://minimal-staging-archives/` mirror (no HTTP Last-Modified oracle), so
tier 5 helps only the https-sourced minority -- the no-provenance residue (~90
toolchains/prebuilts/X11 libs) genuinely needs attrs.released_at or exemption.
(Last-Modified is the artifact's availability/upload time, not strictly the
upstream release date -- close enough for a soak gate, and dwell backstops it.)

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
    # Read the URL the same way source_url does (nested `from.url`, else flat
    # `url`) and match on the path only, ignoring any ?query/#fragment.
    for d in pkg.get("build_deps", []):
        if not (isinstance(d, dict) and d.get("type") == "source"):
            continue
        frm = d.get("from")
        url = (frm.get("url") if isinstance(frm, dict) else None) or d.get("url") or ""
        path = url.split("?", 1)[0].split("#", 1)[0]
        m = re.search(r"\.tar\.([A-Za-z0-9]+)$", path)
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
    """Bounded, ordered, de-duplicated tag guesses for a GitHub repo.

    Two layers, cheapest/most-likely first:
      (A) generic forms from the bare version + repo name. The first eight entries
          are the historical order (bare, v-prefixed, repo-dashed, dots->under-
          scores) -- unchanged so no existing format regresses -- plus repo-derived
          families that plausibly recur: repo+'-v' (bun-v1.3.14), repo+'@'
          (varlock@0.2.3, monorepo per-pkg) and lib-stripped (libfuse->fuse-3.18.2,
          libxkbcommon->xkbcommon-1.13.1).
      (B) bespoke per-repo schemes, keyed on the repo name, each justified by a
          probed upstream tag. Emitted ONLY for their own repo so they don't
          pollute every lookup or risk a cross-repo false hit.

    Pure (no network); <=~14 candidates for any input.
    """
    vu = version.replace(".", "_")     # 8.20.0 -> 8_20_0  (curl, expat, postgres)
    vd = version.replace(".", "-")     # 8.6.16 -> 8-6-16  (tcl core-)
    # openssh-portable: 10.3p1 -> V_10_3_P1 (dots->'_', portable 'p'->'_P', upper)
    v_ssh = ("V_" + version.lower().replace(".", "_").replace("p", "_P")).upper()

    cands = [
        version, f"v{version}",
        f"{repo}-{version}", f"{repo}-{vu}",
        f"{repo}_{version}", f"{repo}_{vu}",
        vu, f"v{vu}",
        f"{repo}-v{version}",          # bun-v1.3.14
        f"{repo}@{version}",           # varlock@0.2.3 (monorepo per-pkg tag)
    ]
    if repo.lower().startswith("lib") and len(repo) > 3:
        base = repo[3:]                # libfuse->fuse, libxkbcommon->xkbcommon
        cands += [f"{base}-{version}", f"{base}-v{version}"]

    # Bespoke schemes keyed on the provenance repo name (value = exact candidate).
    overrides = {
        "libexpat":         [f"R_{vu}"],                   # R_2_7_5
        "postgres":         [f"REL_{vu}"],                 # REL_18_4 (v10+, 2-part)
        "tcl":              [f"core-{vd}"],                # core-8-6-16
        "openssh":          [v_ssh],                       # V_10_3_P1
        "openssh-portable": [v_ssh],                       # V_10_3_P1 (repo alias)
        "llvm-project":     [f"llvmorg-{version}"],        # llvmorg-21.1.8
        "sqlite":           [f"version-{version}"],        # version-3.50.4
        "codex":            [f"rust-v{version}"],          # rust-v0.130.0 (monorepo)
        "tools":            [f"gopls/v{version}"],         # gopls/v0.21.1 (golang/tools)
        "cabal":            [f"cabal-install-v{version}"], # cabal-install-v3.12.1.0
        "Little-CMS":       [f"lcms{version}"],            # lcms2.17
    }
    cands += overrides.get(repo, [])

    seen, out = set(), []
    for c in cands:
        if c not in seen:
            seen.add(c)
            out.append(c)
    return out


def gh_json(path: str) -> dict | None:
    # NOTE: every non-zero exit (404, but also 403 rate-limit / 5xx / network /
    # timeout) collapses to None, which callers read as "no such tag". Fine for
    # the report-only check over a handful of changed packages; a full-catalog
    # sweep should distinguish 403-rate-limit from 404 and bulk-fetch tags.
    try:
        p = subprocess.run(["gh", "api", path], capture_output=True,
                           text=True, timeout=30)
    except subprocess.TimeoutExpired:
        return None
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


# ---- HTTPS HEAD date helper (shared by the GNU + source-URL tiers) ----------

def _curl_head_date(url: str) -> str | None:
    """HEAD an https URL (following https-only redirects) and return the FINAL
    response's Last-Modified as an ISO date, else None.

    Hardening: https-only with `--proto/--proto-redir =https` and bounded
    redirects closes the SSRF / protocol-downgrade surface on attacker-influenced
    (fork-PR) URLs; validating that the FINAL hop is 2xx stops an error page that
    happens to carry a stale Last-Modified from yielding a bogus (often old)
    'release date'. A naive RFC822 datetime is treated as UTC.
    """
    if not url.lower().startswith("https://"):
        return None
    try:
        p = subprocess.run(
            ["curl", "-sIL", "--proto", "=https", "--proto-redir", "=https",
             "--max-redirs", "5", "--max-time", "20", url],
            capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        return None
    if p.returncode != 0 or not p.stdout:
        return None
    # Walk hops; the accepted Last-Modified must belong to the final (2xx) block.
    final_ok, last_mod = False, None
    for ln in p.stdout.splitlines():
        s = ln.strip()
        if s.upper().startswith("HTTP/"):
            parts = s.split()
            final_ok = len(parts) > 1 and parts[1].startswith("2")
            last_mod = None
        elif s.lower().startswith("last-modified:"):
            last_mod = s.split(":", 1)[1].strip()
    if not (final_ok and last_mod):
        return None
    try:
        dt = parsedate_to_datetime(last_mod)
    except (TypeError, ValueError):
        return None
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).date().isoformat()


# ---- GNU date resolution ---------------------------------------------------

# gnu_name -> actual /gnu/<dir> for projects whose tarballs live under a
# different (aliased) project directory than their package name.
_GNU_DIR_ALIASES = {"libidn2": "libidn"}   # /gnu/libidn/libidn2-2.3.8.tar.gz


def gnu_date(name: str, version: str, ext: str | None) -> tuple[str | None, str]:
    exts = [ext] if ext else []
    for e in ("xz", "gz", "bz2", "lz", "zst"):
        if e not in exts:
            exts.append(e)

    base = f"{name}-{version}"
    # Candidate project dirs, most-likely first: the name, an explicit alias, and
    # a trailing-digit-stripped alias (libidn2 -> libidn) as a generic fallback.
    dirs = [name]
    alias = _GNU_DIR_ALIASES.get(name)
    if alias and alias not in dirs:
        dirs.append(alias)
    stripped = re.sub(r"\d+$", "", name)
    if stripped and stripped != name and stripped not in dirs:
        dirs.append(stripped)

    # Per dir, try the flat layout then the per-version nested subdir (gcc).
    stems, seen = [], set()
    for d in dirs:
        for s in (f"{d}/{base}", f"{d}/{base}/{base}"):
            if s not in seen:
                seen.add(s)
                stems.append(s)

    for stem in stems:
        for e in exts:
            d = _curl_head_date(f"https://ftp.gnu.org/gnu/{stem}.tar.{e}")
            if d:
                return d, f"ftp.gnu.org (.tar.{e})"
    return None, "ftp.gnu.org HEAD failed (flat/nested/alias dirs)"


# ---- generic source-URL date (the "date on the file" fallback) -------------

def url_last_modified(url: str) -> tuple[str | None, str]:
    """HEAD the package's own source URL for its Last-Modified date.

    https-only (an http:// or non-http source has no usable oracle here) with
    https-only redirects and final-2xx validation -- see _curl_head_date for the
    SSRF / bogus-date hardening. The URL is taken WHOLE from the spec (the exact
    one the build fetches). NOTE: on a fork PR the URL is attacker-influenceable;
    this is a read-only HEAD on an ephemeral runner with no secrets, but if the
    internal-network reach is unwanted, gate this tier to same-repo PRs -- a
    workflow-level decision this script can't make.

    Last-Modified is the artifact's availability/upload time, not strictly the
    upstream release date -- close enough for a soak gate, and dwell backstops it.
    """
    if not url.lower().startswith("https://"):
        return None, "non-https source (no Last-Modified oracle)"
    d = _curl_head_date(url)
    if d:
        return d, "source-url Last-Modified"
    return None, "source-url: no usable Last-Modified (non-2xx or absent)"


# ---- per-package resolution ------------------------------------------------

def self_dated_version(version: str) -> str | None:
    """Some projects encode the release date in the version as a trailing
    YYYYMMDD (ncurses weekly snapshots; other Thomas Dickey projects --
    xterm/lynx/dialog/vile). That suffix IS the release date: parse it directly,
    no network and no upstream archive needed (the dated tarball is often GC'd
    upstream once superseded). Requires a separator before the 8 digits so a
    normal dotted version can't false-match."""
    m = re.search(r"(?:^|[-_.])(\d{8})$", version)
    if not m:
        return None
    try:
        return datetime.strptime(m.group(1), "%Y%m%d").date().isoformat()
    except ValueError:
        return None


def resolve(pkg: dict) -> tuple[str, str | None, str, str]:
    """Return (version, date|None, source_type, date_source_detail)."""
    attrs = pkg.get("attrs") or {}
    version = attr_str(attrs, "upstream_version") or "?"
    declared = attr_str(attrs, "released_at")
    prov = provenance(attrs)
    src_type = (prov or {}).get("category") or "no-provenance"

    if declared:
        return version, declared, src_type, "attrs.released_at"

    # Self-dating snapshot versions (e.g. ncurses 6.5-20250830) carry their date
    # in the version string -- resolve with zero network before any other tier.
    sd = self_dated_version(version)
    if sd:
        return version, sd, src_type, "self-dated snapshot (version suffix)"

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

def md_cell(s: str) -> str:
    """Escape an untrusted build.ncl value for one Markdown table cell / code
    span: neutralize column-splitting `|`, row-splitting newlines, and backticks
    (backslash first, so the escapes we add aren't themselves doubled)."""
    return (str(s).replace("\\", "\\\\").replace("|", "\\|")
            .replace("`", "\\`").replace("\r", " ").replace("\n", " "))


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

    by_name = {p["name"]: p for p in catalog
               if isinstance(p, dict) and isinstance(p.get("name"), str)}

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
        out.append("| " + " | ".join(md_cell(c) for c in r) + " |")
    out += ["",
            "> This check never blocks merge and is intentionally excluded from "
            "branch-protection required checks. ⏳ = too fresh to promote "
            "*today*; ❓ = no derivable date."]
    if unknown:
        out += ["", "### ❓ Missing `attrs.released_at`", "",
                "These packages have no GitHub/GNU source to derive a date from "
                "(or an unsafe identifier). Backfill a verified UTC date:", "",
                "```nickel", 'attrs.released_at = "YYYY-MM-DD",', "```", "",
                *[f"- `{md_cell(n)}`" for n in unknown]]

    emit("\n".join(out) + "\n")
    return 0  # report-only: success regardless of verdicts


if __name__ == "__main__":
    sys.exit(main())
