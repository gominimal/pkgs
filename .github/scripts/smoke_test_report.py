#!/usr/bin/env python3
"""Report-only smoke-test-coverage check (gominimal/inbox#20 criterion, #21).

An inbox#20 entry-to-`main` criterion: each package should carry >=1 *Standalone*
test in its buildspec -- a test that meaningfully exercises the package's
functionality, distinct from the upstream project's own `make test`. This check
reports, per package, whether such a test is present. It is REPORT-ONLY: it never
exits non-zero for a coverage verdict (missing test), only for a programming
error, which the workflow downgrades to a warning. It MUST NOT be a
branch-protection required check.

Detection (either form, per packages/<name>/build.ncl):
  - the `standaloneTest "<cmd>"` helper, or
  - an explicit `class = 'Standalone` on a `Test` record.

This only detects *presence*; whether a test "meaningfully" exercises the package
is a human judgment the check can't make. Purely reads tracked build.ncl text --
no dump, no network, no secrets, no injection surface (untrusted values are still
Markdown-escaped before they reach the summary).

Modes:
  --all                  every package in the catalog (coverage dashboard).
  --packages-file FILE   an explicit newline-delimited package list (a PR passes
                         the packages it changed).
"""

from __future__ import annotations

import argparse
import os
import re
import sys


# Either the `standaloneTest "..."` helper or an explicit `class = 'Standalone`.
# `standaloneTest` alone is enough (the helper sets class='Standalone internally);
# the explicit form covers packages that build a Test record by hand.
_STANDALONE_RE = re.compile(r"standaloneTest\b|class\s*=\s*'Standalone\b")


def has_standalone_test(name: str) -> bool | None:
    """True/False if packages/<name>/build.ncl has a Standalone test; None if the
    build.ncl can't be read (renamed/deleted)."""
    try:
        with open(os.path.join("packages", name, "build.ncl"), encoding="utf-8") as f:
            return bool(_STANDALONE_RE.search(f.read()))
    except OSError:
        return None


def list_packages() -> list[str]:
    try:
        return sorted(d for d in os.listdir("packages")
                      if os.path.isfile(os.path.join("packages", d, "build.ncl")))
    except OSError:
        return []


def md_cell(s: str) -> str:
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
                     help="report coverage over the whole catalog")
    grp.add_argument("--packages-file",
                     help="newline-delimited package names to report")
    args = ap.parse_args()

    if args.all:
        names = list_packages()
    else:
        try:
            with open(args.packages_file) as f:
                names = [ln.strip() for ln in f if ln.strip()]
        except OSError as e:
            emit("## smoke-test coverage (informational, non-blocking)\n\n"
                 f"> Could not read packages file ({type(e).__name__}); "
                 "skipping. Non-blocking.\n")
            return 0

    covered, missing, unresolved = [], [], []
    for name in names:
        has = has_standalone_test(name)
        if has is None:
            unresolved.append(name)
        elif has:
            covered.append(name)
        else:
            missing.append(name)
        print(f"{name}: "
              f"{'standalone-test' if has else 'MISSING' if has is not None else 'unresolved'}")

    total = len(covered) + len(missing)
    pct = f"{100 * len(covered) // total}%" if total else "n/a"

    out = [
        "## smoke-test coverage (informational, non-blocking)", "",
        "inbox#20 entry criterion: each package should carry ≥1 **Standalone** "
        "buildspec test (`standaloneTest \"...\"` or `class = 'Standalone`) that "
        "meaningfully exercises it — distinct from the upstream project's own "
        "tests.", "",
        f"**{len(covered)}/{total} covered ({pct})** · **{len(missing)} missing** "
        + (f"· {len(unresolved)} unresolved" if unresolved else ""),
        "",
    ]
    if missing:
        out += [
            "### ❌ No Standalone test", "",
            "These packages have no Standalone test block. Add one that runs the "
            "built binary (e.g. a `--version`/`--help` smoke, or a real "
            "functional check):", "",
            "```nickel",
            'tests = { smoketest = standaloneTest "/bin/<prog> --version" },',
            "```", "",
            *[f"- `{md_cell(n)}`" for n in sorted(missing)],
        ]
    else:
        out.append("✅ All reported packages carry a Standalone test.")
    if unresolved:
        out += ["", "### ⚠️ Unresolved (no readable build.ncl)", "",
                *[f"- `{md_cell(n)}`" for n in sorted(unresolved)]]
    out += ["",
            "> Report-only; never blocks and is intentionally excluded from "
            "branch-protection required checks. Presence only — whether a test "
            "*meaningfully* exercises the package is a human call."]

    emit("\n".join(out) + "\n")
    return 0  # report-only


if __name__ == "__main__":
    sys.exit(main())
