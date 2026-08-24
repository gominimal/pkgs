#!/usr/bin/env python3
"""Report-only DWELL (soak) check for main -> stable promotion (inbox#20/#21).

The soak gate is DWELL: how long a package's *current version* has lived on
`main`, git-derived (not upstream release age -- that's #279's advisory signal).
A package is eligible to promote main -> stable once its main version has dwelled
>= a reference minimum (default 7 days, gominimal/inbox#20; Debian britney2
minimum-soak precedent).

This script is PURE GIT: no `minimal dump`, no network, no secrets. It NEVER
exits non-zero for a policy reason (still-soaking / unknown) -- it only reports,
appending a Markdown table to $GITHUB_STEP_SUMMARY. It exits non-zero solely on a
programming error, which the workflow downgrades to a warning. It MUST NOT be a
branch-protection required check.

Dwell of package P (version V on main):
  the commit date at which "V" was last introduced to packages/P/build.ncl on
  `main` (first-parent). Found with a single `git log -S` pickaxe on the exact
  quoted token `"V"` -- quoting both sides so a version prefix (1.2.3) can't
  false-match a longer one (1.2.30). A non-version edit to build.ncl does not
  reset dwell, because the introduction of V predates it.

Modes:
  --all                  every package whose main version differs from stable
                         (the promotion candidates); the dashboard.
  --packages-file FILE   an explicit newline-delimited package list (a promotion
                         PR passes the packages it would change on stable).

Versions/paths come from tracked build.ncl only; nothing is composed into a URL
or a shell, so there is no SSRF/injection surface here (unlike #279). Untrusted
values are still Markdown-escaped before they reach the summary table.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from datetime import datetime, timezone


# `let version = "X.Y.Z" in` is the canonical version binding in every build.ncl
# (upstream_version = version). Anchored to the start of a line (re.M).
_VERSION_RE = re.compile(r'^\s*let\s+version\s*=\s*"([^"]+)"', re.M)


def git(*args: str, timeout: int = 60) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], capture_output=True, text=True,
                          timeout=timeout)


def version_at(ref: str, name: str) -> str | None:
    """The `let version` binding of packages/<name>/build.ncl at a git ref, or
    None if the file/binding is absent (deleted, pre-dating the convention)."""
    p = git("show", f"{ref}:packages/{name}/build.ncl")
    if p.returncode != 0:
        return None
    m = _VERSION_RE.search(p.stdout)
    return m.group(1) if m else None


def dwell_start(branch: str, name: str, version: str) -> str | None:
    """ISO date at which `version` was last introduced to the package's build.ncl
    on `branch` (first-parent history). One pickaxe call; the newest match is the
    (re-)introduction of the current version. None if not derivable."""
    # -S is a FIXED string (not regex); quote both sides so 1.2.3 can't match
    # inside 1.2.30. Passed as a list arg, so no shell/globbing concerns.
    p = git("log", "--first-parent", branch, "--format=%cI",
            "-S", f'"{version}"', "--", f"packages/{name}/build.ncl")
    if p.returncode != 0:
        return None
    lines = [ln.strip() for ln in p.stdout.splitlines() if ln.strip()]
    if lines:
        return lines[0]  # newest count-change of "version" == its introduction
    # Fallback: the file's most recent touch on the branch (version predates any
    # recorded pickaxe change, e.g. introduced in the file's first commit under a
    # squash that the pickaxe attributes elsewhere). Better an approximate floor
    # than UNKNOWN.
    p = git("log", "--first-parent", branch, "-1", "--format=%cI", "--",
            f"packages/{name}/build.ncl")
    lines = [ln.strip() for ln in p.stdout.splitlines() if ln.strip()]
    return lines[0] if lines else None


def dwell_days(iso: str | None) -> int | None:
    if not iso:
        return None
    # git %cI emits a trailing "Z" for UTC commits; datetime.fromisoformat only
    # accepts "Z" on Python 3.11+. Normalize so this works on the CI runner AND
    # an older local interpreter (matches version_age_report.py's care here).
    s = iso.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return (datetime.now(timezone.utc) - dt).days


def list_packages(ref: str) -> list[str]:
    """Package directory names at `ref` (tracked, not the working tree)."""
    p = git("ls-tree", "-d", "--name-only", ref, "packages/")
    if p.returncode != 0:
        # Fall back to the working tree (checkout is the branch under report).
        try:
            return sorted(d for d in os.listdir("packages")
                          if os.path.isdir(os.path.join("packages", d)))
        except OSError:
            return []
    return sorted(ln.split("/", 1)[1] for ln in p.stdout.splitlines()
                  if ln.startswith("packages/") and "/" in ln)


def md_cell(s: str) -> str:
    """Escape an untrusted build.ncl value for one Markdown table cell."""
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
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--all", action="store_true",
                     help="report every package whose main version differs from stable")
    grp.add_argument("--packages-file",
                     help="newline-delimited package names to report")
    ap.add_argument("--main-ref", default="origin/main")
    ap.add_argument("--stable-ref", default="origin/stable")
    ap.add_argument("--min-dwell-days", type=int, default=7)  # #20 soak reference
    args = ap.parse_args()

    # Resolve refs defensively: on some events origin/<b> may be absent but the
    # local branch exists. Fall back local, then to HEAD for main.
    def resolve_ref(preferred: str, local: str) -> str | None:
        for r in (preferred, local):
            if git("rev-parse", "--verify", "--quiet", r).returncode == 0:
                return r
        return None

    main_ref = resolve_ref(args.main_ref, "main")
    stable_ref = resolve_ref(args.stable_ref, "stable")
    if main_ref is None:
        emit("## dwell report (informational, non-blocking)\n\n"
             "> Could not resolve the `main` ref; skipping. Non-blocking.\n")
        return 0
    if stable_ref is None:
        emit("## dwell report (informational, non-blocking)\n\n"
             "> Could not resolve the `stable` ref (does it exist yet?); "
             "skipping. Non-blocking.\n")
        return 0

    if args.all:
        names = list_packages(main_ref)
    else:
        try:
            with open(args.packages_file) as f:
                names = [ln.strip() for ln in f if ln.strip()]
        except OSError as e:
            emit("## dwell report (informational, non-blocking)\n\n"
                 f"> Could not read packages file ({type(e).__name__}); "
                 "skipping. Non-blocking.\n")
            return 0

    rows = []
    promotable = soaking = unknown = in_stable = 0
    for name in names:
        mv = version_at(main_ref, name)
        sv = version_at(stable_ref, name)
        if mv is None:
            # Not a versioned package (meta/renamed); nothing to soak.
            continue
        if mv == sv:
            in_stable += 1
            if not args.all:  # explicit list: still show it as already-in-stable
                rows.append((name, mv, "—", sv or "—", "· already in stable"))
            continue
        # main differs from stable -> a promotion candidate. Measure its dwell.
        days = dwell_days(dwell_start(main_ref, name, mv))
        if days is None:
            unknown += 1
            verdict = "❓ dwell unknown"
            dcell = "—"
        elif days >= args.min_dwell_days:
            promotable += 1
            verdict = "✅ promotable"
            dcell = str(days)
        else:
            soaking += 1
            verdict = f"⏳ soaking ({days}/{args.min_dwell_days}d)"
            dcell = str(days)
        rows.append((name, mv, dcell, sv or "— (new)", verdict))
        print(f"{name} main={mv} stable={sv} dwell={dcell}d -> {verdict}")

    # Promotable first, then soaking (closest to eligible first), then unknown.
    def sort_key(r):
        v = r[4]
        rank = 0 if v.startswith("✅") else 1 if v.startswith("⏳") else 2 if v.startswith("❓") else 3
        # within soaking, more-soaked first
        try:
            d = -int(r[2])
        except (ValueError, TypeError):
            d = 0
        return (rank, d, r[0])
    rows.sort(key=sort_key)

    out = [
        "## dwell report (informational, non-blocking)", "",
        f"Soak reference: **{args.min_dwell_days} days** dwell in `main` "
        "(gominimal/inbox#20; Debian britney2 minimum-soak precedent). "
        "Dwell is git-derived — how long each package's *current* `main` version "
        "has lived there.", "",
        f"**{promotable} promotable** · **{soaking} soaking** · "
        f"**{unknown} dwell-unknown** · {in_stable} already in `stable`.", "",
    ]
    if rows:
        out += [
            "| package | main version | dwell (days) | stable version | status |",
            "| --- | --- | ---: | --- | --- |",
        ]
        for r in rows:
            out.append("| " + " | ".join(md_cell(c) for c in r) + " |")
    else:
        out.append("_No packages differ between `main` and `stable`._")
    out += [
        "",
        "> Report-only; intentionally excluded from branch-protection required "
        "checks. ✅ = its `main` version has soaked long enough to promote to "
        "`stable` *today*; ⏳ = still soaking; ❓ = dwell not derivable from git.",
    ]
    emit("\n".join(out) + "\n")
    return 0  # report-only: success regardless of verdicts


if __name__ == "__main__":
    sys.exit(main())
