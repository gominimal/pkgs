#!/usr/bin/env python3
"""Decide what a pull request's minimal-check must cover.

Reads the PR's changed files (the pulls/<n>/files API records: `filename`,
`previous_filename` on a rename, `status`) and writes `mode=full|scoped|none`
plus, for `scoped`, the `packages=` and `stacks=` lists to GITHUB_OUTPUT.

A scoped check covers each touched package AND every package that depends on
it, transitively, plus the stacks that name any of those. A change that is
only right for its own package can still break its importers (renaming gcc's
`libstdcpp` output breaks every `subsetOf gcc` caller), so checking the
touched directories alone would pass a PR that breaks the catalog. The graph
is blast_radius_report.load_graph: every `"../<pkg>/` path in any .ncl under a
package directory, so an edit to a shared helper (hex0's amd64-ladder.ncl)
reaches the packages that import it.

Everything falls back to the full check whenever the scope cannot be trusted
or would not be cheaper:

- the API returned fewer records than the PR's `changed_files` (the files
  endpoint stops at 3,000, and `--paginate` does not lift that);
- a file outside packages/<pkg>/ and stacks/<stack>/ changed (workflows,
  scripts, minimal.toml, or a loose file such as packages/common.ncl);
- a package or stack directory is gone: `mip check` would be handed a name
  that no longer exists, and its former importers need checking anyway;
- the scoped set exceeds MAX_SCOPED packages. The dependents distribution has
  a gap there: 485 of 593 packages reach at most 48 others, and past that it
  climbs quickly (go 57, git 73, gettext 103, then 140+). Those wide packages
  are where breakage spreads, and checking 50+ packages costs most of what
  the full check does.

A rename counts both its paths, so moving a file out of a package checks the
package it left, and renaming stack.ncl to NOTES.md is not mistaken for prose.
Only prose (*.md outside packages/ and stacks/, legal/) and tests/<name>/
projects are set aside; a PR of nothing else checks nothing. A .md inside a
recipe directory is NOT prose: a package can ship one (`{ file = "NOTES.md" }
| Local`, or read it from build.sh), so editing it checks that package. A tests/<name>/ directory is a
self-contained min project with its own [upstream] pin (AGENTS.md "Tests",
gominimal/pkgs#976): mip never evaluates it as a package, so it cannot break
one, and its own workflow (if any) runs it. A loose file directly under
tests/ is not a project and still runs the full check.
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blast_radius_report import load_graph, transitive_dependents  # noqa: E402

MAX_SCOPED = 50
PROSE_RE = re.compile(r"^(?!(packages|stacks)/)(.*/)?[^/]*\.md$|^legal/")
TESTS_RE = re.compile(r"^tests/[^/]+/")
SCOPED_RE = re.compile(r"^(packages|stacks)/([^/]+)/")


def decide(records, changed_files, root: Path, max_scoped=MAX_SCOPED):
    """Return (mode, packages, stacks, reasons). packages/stacks are sorted lists."""
    reasons = []
    if changed_files is not None and len(records) != changed_files:
        return "full", [], [], [
            f"the files API returned {len(records)} of the PR's {changed_files} changed files"
        ]

    paths = []
    for r in records:
        paths.append(r["filename"])
        if r.get("previous_filename"):
            paths.append(r["previous_filename"])
    code = [p for p in paths if not PROSE_RE.search(p) and not TESTS_RE.match(p)]

    other = [p for p in code if not SCOPED_RE.match(p)]
    if other:
        return "full", [], [], ["the PR changes files outside packages/<name>/ and stacks/<name>/:"] + [
            "  " + p for p in sorted(set(other))
        ]

    seed_pkgs, seed_stacks = set(), set()
    for p in code:
        kind, name = SCOPED_RE.match(p).groups()
        (seed_pkgs if kind == "packages" else seed_stacks).add(name)
    if not seed_pkgs and not seed_stacks:
        return "none", [], [], ["the PR changes only prose or tests/<name>/ projects"]

    gone = sorted(
        [f"packages/{n}" for n in seed_pkgs if not (root / "packages" / n / "build.ncl").is_file()]
        + [f"stacks/{n}" for n in seed_stacks if not (root / "stacks" / n / "stack.ncl").is_file()]
    )
    if gone:
        return "full", [], [], ["the PR removes " + ", ".join(gone) + "; whatever used it needs checking"]

    pkgs, importers, name_refs = load_graph(root)
    scoped = set(seed_pkgs)
    for p in seed_pkgs:
        deps = transitive_dependents(p, importers)
        scoped |= deps
        if deps:
            reasons.append(f"{p}: {len(deps)} dependent package(s)")
    if len(scoped) > max_scoped:
        return "full", [], [], reasons + [
            f"the scoped set is {len(scoped)} packages, over the {max_scoped} limit"
        ]

    stacks = set(seed_stacks)
    for p in scoped:
        for ref in name_refs.get(p, ()):
            m = re.match(r"^stacks/([^/]+)/stack\.ncl$", ref)
            if m:
                stacks.add(m.group(1))
    return "scoped", sorted(scoped), sorted(stacks), reasons


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--files-jsonl", required=True, help="pulls/<n>/files records, one JSON object per line"
    )
    ap.add_argument("--changed-files", type=int, required=True, help="the PR's changed_files count")
    ap.add_argument("--root", default=".")
    args = ap.parse_args()

    records = [json.loads(line) for line in Path(args.files_jsonl).read_text().splitlines() if line.strip()]
    mode, packages, stacks, reasons = decide(records, args.changed_files, Path(args.root).resolve())

    headline = {
        "full": "full check",
        "none": "nothing to check",
        "scoped": f"scoped check: {len(packages)} package(s), {len(stacks)} stack(s)",
    }[mode]
    print(headline)
    for r in reasons:
        print("  " + r)
    if mode == "scoped":
        print("  packages: " + " ".join(packages))
        print("  stacks: " + (" ".join(stacks) or "-"))

    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as fh:
            fh.write(f"mode={mode}\n")
            if mode == "scoped":
                # Ten packages or fewer don't need the disk-free step.
                fh.write("small=" + ("true" if len(packages) <= 10 else "false") + "\n")
                fh.write("packages=" + ",".join(packages) + "\n")
                fh.write("stacks=" + ",".join(stacks) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
