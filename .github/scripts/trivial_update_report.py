#!/usr/bin/env python3
"""Report-only trivial-update diff-audit (gominimal/inbox#20 criterion, #21).

inbox#20's `#trivial` fast-path: a package update is *trivial* when it changes
nothing but the version and its source hash(es), and the version increases -- no
new features, no dependency/build/patch changes. Such updates can promote on a
green build without functional re-validation. This check audits each changed
package's build.ncl diff and reports trivial vs non-trivial (naming the lines
that make it non-trivial). REPORT-ONLY: it never exits non-zero for a verdict,
only for a programming error (downgraded to a warning by the workflow), and MUST
NOT be a branch-protection required check.

A change is trivial iff, in packages/<name>/build.ncl (base..head):
  - every added/removed line is a `version = "..."` or a `*sha256 = "..."`, AND
  - the version is present in the change and strictly increases.

Anything else (new dep import, patch, build-step edit, attr change, a bare
sha256 re-pin with no version bump) -> non-trivial. Conservative by design: a
false "non-trivial" just means the normal review path; a false "trivial" would
wave through a functional change, so the bar is "only version+hash, nothing else".

Pure git; no dump, no network, no secrets. Untrusted build.ncl text is
Markdown-escaped before it reaches the summary.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys


_VER_RE = re.compile(r'^\s*(?:let\s+)?version\s*=\s*"([^"]*)"')
# sha256, amd64_sha256, arm64_sha256, <anything>_sha256
_SHA_RE = re.compile(r'^\s*[A-Za-z0-9_]*sha256\s*=\s*"[^"]*"')


def git(*args: str, timeout: int = 60) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], capture_output=True, text=True,
                          timeout=timeout)


def classify_line(s: str) -> str:
    if _VER_RE.search(s):
        return "version"
    if _SHA_RE.search(s):
        return "sha256"
    if s.strip() == "":
        return "blank"
    return "other"


def version_of(lines: list[str]) -> str | None:
    for ln in lines:
        m = _VER_RE.search(ln)
        if m:
            return m.group(1)
    return None


def version_tuple(v: str) -> tuple:
    # Loose numeric tuple: split on any non-digit run, keep integer parts. Works
    # for semver (1.2.3), date-versions (20260526.0), and 2.46.1-style. Trailing
    # non-numeric (rc/beta) is dropped -- fine for a monotonic-increase heuristic.
    return tuple(int(x) for x in re.findall(r"\d+", v))


def audit(base: str, head: str, name: str) -> dict:
    p = git("diff", base, head, "--", f"packages/{name}/build.ncl")
    if p.returncode != 0:
        return {"verdict": "unresolved", "reason": "diff failed"}
    added, removed = [], []
    for ln in p.stdout.splitlines():
        if ln[:3] in ("+++", "---") or ln.startswith("@@"):
            continue
        if ln.startswith("+"):
            added.append(ln[1:])
        elif ln.startswith("-"):
            removed.append(ln[1:])

    changed = added + removed
    if not changed:
        return {"verdict": "no-change", "reason": "no build.ncl diff"}

    others = [ln for ln in changed if classify_line(ln) == "other"]
    old_v = version_of(removed)
    new_v = version_of(added)

    if others:
        # Name up to a few offending lines so the reason is actionable.
        sample = "; ".join(s.strip() for s in others[:3])
        return {"verdict": "non-trivial", "old": old_v, "new": new_v,
                "reason": f"{len(others)} non-version/sha256 line(s): {sample}"}

    if new_v is None or old_v is None:
        # Only sha256 (or blank) changed -- a re-pin with no version bump.
        return {"verdict": "non-trivial", "old": old_v, "new": new_v,
                "reason": "hash changed without a version bump"}

    try:
        increased = version_tuple(new_v) > version_tuple(old_v)
    except (ValueError, TypeError):
        increased = None
    if increased is False:
        return {"verdict": "non-trivial", "old": old_v, "new": new_v,
                "reason": "version did not increase"}

    note = "" if increased else " (version order unverified)"
    return {"verdict": "trivial", "old": old_v, "new": new_v,
            "reason": f"version + hash only{note}"}


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
    ap.add_argument("--packages-file", required=True)
    ap.add_argument("--base-sha", required=True)
    ap.add_argument("--head-sha", required=True)
    args = ap.parse_args()

    try:
        with open(args.packages_file) as f:
            names = [ln.strip() for ln in f if ln.strip()]
    except OSError as e:
        emit("## trivial-update audit (informational, non-blocking)\n\n"
             f"> Could not read packages file ({type(e).__name__}); skipping.\n")
        return 0

    rows, trivial, nontrivial = [], 0, 0
    for name in names:
        r = audit(args.base_sha, args.head_sha, name)
        v = r["verdict"]
        if v == "trivial":
            trivial += 1
            icon = "✅ trivial"
        elif v == "non-trivial":
            nontrivial += 1
            icon = "🔎 non-trivial"
        else:
            icon = f"— {v}"
        vc = (f"{r.get('old') or '—'} → {r.get('new') or '—'}"
              if r.get("old") or r.get("new") else "—")
        rows.append((name, icon, vc, r.get("reason", "")))
        print(f"{name}: {v} ({r.get('reason','')})")

    all_trivial = nontrivial == 0 and trivial > 0
    out = [
        "## trivial-update audit (informational, non-blocking)", "",
        "inbox#20 `#trivial` fast-path: an update is *trivial* when only the "
        "version and source hash(es) change and the version increases — no new "
        "features/deps/patches, so it can promote on a green build without "
        "functional re-validation.", "",
        (f"**✅ All {trivial} changed package(s) are trivial** — eligible for the "
         "`#trivial` fast-path." if all_trivial
         else f"**{trivial} trivial · {nontrivial} non-trivial** — this PR is "
              "**not** wholly trivial; the non-trivial packages take the normal "
              "review path."),
        "",
        "| package | verdict | version | why |",
        "| --- | --- | --- | --- |",
    ]
    for r in rows:
        out.append("| " + " | ".join(md_cell(c) for c in r) + " |")
    out += ["",
            "> Report-only; never blocks and is excluded from branch-protection "
            "required checks. Conservative: anything beyond version+hash is "
            "non-trivial. A `#trivial` PR label should be cross-checked against "
            "this audit."]
    emit("\n".join(out) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
