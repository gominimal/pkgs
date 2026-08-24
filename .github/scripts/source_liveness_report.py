#!/usr/bin/env python3
"""Report-only upstream source-liveness check (gominimal/pkgmgr-rs#447).

Probe the DIRECT-UPSTREAM source URLs — the ones not served from
gs://minimal-staging-archives — and report the ones that have gone away.

Why this can't ride on `pkgmgr update`: an update run only touches packages it
is attempting to bump, so a package sitting at the latest version never
exercises its source URL. Its tarball can 404 for months and the first symptom
is a build failure at the worst possible moment — during a security bump, when
the mirror is the thing you need.

WHAT THIS CAN AND CANNOT ANSWER — read before acting on a row.

  gone       404 / 410. The object is not there. Actionable: mirror it
             (`pkgmgr mirror --package X --version Y`) or repoint the URL.
  ok         200 / 3xx. Present, from a GitHub Actions runner's egress.
  unknown    Timeout, TLS failure, 403, 5xx, or any other code. NOT actionable.

`unknown` is deliberately a large bucket, and collapsing it into `gone` is the
single easiest way to make this report useless. A GitHub Actions runner has
different egress than the Minimal build sandbox and than the Cloud Run runner:
ftp.gnu.org answers 403 to the sandbox while serving this runner fine, and
sourceforge/kernel.org rate-limit by source IP. Over one weekend of manual
checks, 2 of 4 apparent failures were egress-specific rather than real. So a
non-404 is reported as "we could not tell from here", never as a fault.

This is a liveness check, not a mirror-coverage check — see
corresponding_source_report.py for the latter. The two are complementary: that
one asks "is our copy there", this one asks "is upstream's copy still there".

Network: unauthenticated HTTPS HEADs against the hosts named in tracked
build.ncl files. No secrets, no auth, no downloads (HEAD only, capped body).

REPORT-ONLY: exits 0 for any policy verdict; non-zero only on a programming
error (downgraded to a warning by the workflow). MUST NOT be a required check.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from collections import Counter

_URL_RE = re.compile(r'^\s*url\s*=\s*"([^"]+)"', re.M)
_LET_RE = re.compile(r'^\s*let\s+([A-Za-z_][A-Za-z0-9_-]*)\s*=\s*"([^"]*)"\s+in\s*$', re.M)
_INTERP_RE = re.compile(r"%\{([A-Za-z_][A-Za-z0-9_-]*)\}")
_MIRROR = "gs://minimal-staging-archives/"
# Same charset gate the sibling report uses, widened for query strings and the
# `:` in a port-less scheme-relative path. Anything failing it is reported
# unresolved rather than fetched — no SSRF surface from a malformed build.ncl.
_SAFE_URL = re.compile(r"^https://[A-Za-z0-9_.~:/?#\[\]@!$&'()*+,;=%-]+$")


def resolve_interpolations(url: str, lets: dict[str, str]) -> str:
    # let-bindings can reference each other (dl_base uses %{version}); a few
    # passes of textual substitution resolves the practical cases.
    for _ in range(5):
        expanded = _INTERP_RE.sub(lambda m: lets.get(m.group(1), m.group(0)), url)
        if expanded == url:
            break
        url = expanded
    return url


def probe(url: str) -> tuple[str, str]:
    """(verdict, detail). See the module docstring for what each one means."""
    if not _SAFE_URL.match(url):
        return "unresolved", "not a plain https URL (unresolved interpolation?)"
    try:
        p = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
             "--head", "--location", "--proto", "=https", "--max-time", "25",
             "--user-agent", "gominimal-source-liveness/1.0", url],
            capture_output=True, text=True, timeout=40)
    except (subprocess.TimeoutExpired, OSError) as e:
        return "unknown", f"probe failed ({type(e).__name__})"
    code = p.stdout.strip()
    if code in ("404", "410"):
        return "gone", code
    if code.startswith("2") or code.startswith("3"):
        return "ok", code
    # 403 / 429 / 5xx / 000 (connect failure) all land here ON PURPOSE.
    return "unknown", code or "no response"


def md_cell(s) -> str:
    return (str(s).replace("\\", "\\\\").replace("|", "\\|")
            .replace("`", "\\`").replace("\r", " ").replace("\n", " "))


def emit(markdown: str) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a") as f:
            f.write(markdown)
    else:
        print("\n" + markdown)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0,
                    help="probe at most N URLs (0 = no cap)")
    args = ap.parse_args()

    try:
        names = sorted(d for d in os.listdir("packages")
                       if os.path.isfile(os.path.join("packages", d, "build.ncl")))
    except OSError:
        emit("## source-liveness\n\nNo `packages/` directory — nothing to check.\n")
        return 0

    targets: list[tuple[str, str]] = []
    for name in names:
        try:
            src = open(os.path.join("packages", name, "build.ncl")).read()
        except OSError:
            continue
        lets = dict(_LET_RE.findall(src))
        for raw in _URL_RE.findall(src):
            url = resolve_interpolations(raw, lets)
            # gs:// sources are the mirror's problem, and
            # corresponding_source_report.py already watches those.
            if url.startswith(_MIRROR) or not url.startswith("https://"):
                continue
            targets.append((name, url))

    # Deduplicate: several packages legitimately share one upstream URL, and
    # probing it N times is N times the rate-limit exposure for no new signal.
    seen: dict[str, str] = {}
    for name, url in targets:
        seen.setdefault(url, name)
    unique = sorted((n, u) for u, n in seen.items())

    capped = 0
    if args.limit and len(unique) > args.limit:
        capped = len(unique) - args.limit
        unique = unique[:args.limit]

    rows: list[tuple[str, str, str, str]] = []
    counts: Counter[str] = Counter()
    for name, url in unique:
        verdict, detail = probe(url)
        counts[verdict] += 1
        rows.append((verdict, name, url, detail))

    order = {"gone": 0, "unresolved": 1, "unknown": 2, "ok": 3}
    rows.sort(key=lambda r: (order.get(r[0], 9), r[1]))

    icon = {"gone": "❌", "unknown": "❓", "unresolved": "❔", "ok": "✅"}
    out = ["## source-liveness (report-only)\n",
           f"\nProbed **{len(unique)}** distinct direct-upstream URLs across "
           f"{len(names)} packages. `gs://` sources are excluded — those are "
           "covered by the corresponding-source report.\n",
           f"\n**{counts['gone']} gone · {counts['unknown']} unknown · "
           f"{counts['unresolved']} unresolved · {counts['ok']} ok**\n"]

    if capped:
        # A silent cap reads as "everything was checked". Say what was dropped.
        out.append(f"\n> ⚠️ `--limit` dropped **{capped}** URLs from this run; "
                   "they were NOT probed.\n")

    if counts["gone"]:
        out.append("\n> ❌ **Gone** means a 404/410 — the source a build.ncl "
                   "points at no longer exists upstream. Fix by mirroring "
                   "(`pkgmgr mirror --package X --version Y`) and repointing "
                   "the URL at `gs://minimal-staging-archives/`.\n")
    if counts["unknown"]:
        out.append("\n> ❓ **Unknown** is not a failure. A GitHub Actions "
                   "runner's egress differs from the build sandbox's and the "
                   "Cloud Run runner's — ftp.gnu.org 403s the sandbox while "
                   "serving this runner, and several hosts rate-limit by "
                   "source IP. Treat these as unmeasured, not broken.\n")

    out.append("\n| | package | url | detail |\n|---|---|---|---|\n")
    for verdict, name, url, detail in rows:
        out.append(f"| {icon.get(verdict, '·')} | {md_cell(name)} | "
                   f"{md_cell(url)} | {md_cell(detail)} |\n")

    emit("".join(out))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001 — report-only; never fail the job
        print(f"source_liveness_report: {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(1)
