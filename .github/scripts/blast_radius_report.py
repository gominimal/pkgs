#!/usr/bin/env python3
"""Blast-radius report for changed packages (report-only).

For each changed package, answers: if this update is wrong, what breaks?

- TRUE LEAF ......... no recipe imports it, no stack/profile/harness names it;
                      the blast radius is the package itself.
- LEAF, REFERENCED .. no recipe imports it, but a non-package .ncl (stack,
                      profile, ...) references it by name — sessions/stacks
                      built from those definitions are affected.
- N DEPENDENTS ...... other recipes import it; both the direct importers and
                      the full transitive dependent closure are reported,
                      because "zlib: 62 direct" understates a rebuild that
                      transitively reaches most of the catalog.

Dependency edges come from two places, both computed from the checkout with
no network and no `minimal dump`:

1. Recipe imports: `import "../<pkg>/build.ncl"` in packages/*/build.ncl —
   the real dependency graph as recipes express it (build and runtime deps
   are both declared this way).
2. Name references: any quoted string in a non-package .ncl (stacks/,
   profiles/, ...) matching a package name. Stacks reference packages by
   name (`build_packages = ["go", ...]`), not by import, so an import-only
   scan silently misclassifies them as leaves. String matching over-demotes
   (a quoted word that happens to equal a package name counts) — that is the
   safe direction for a classifier whose consumers may one day fast-path
   "leaf" updates; see inbox#20 for the #trivial fast-path this composes
   with.

The final summary line is stable and machine-readable on purpose:
`blast-radius: ALL-TRUE-LEAVES` or `blast-radius: HAS-DEPENDENTS` — a future
automation lane (auto-merge for trivial leaf bumps) can key on it without
re-parsing the table.
"""

import argparse
import os
import re
import sys
from pathlib import Path

IMPORT_RE = re.compile(r'import "\.\./([a-z0-9_.+-]+)/build\.ncl"')
STRING_RE = re.compile(r'"([a-z0-9_.+-]+)"')


def load_graph(root: Path):
    pkg_dir = root / "packages"
    pkgs = {p.name for p in pkg_dir.iterdir() if (p / "build.ncl").is_file()}
    importers = {p: set() for p in pkgs}
    for p in sorted(pkgs):
        src = (pkg_dir / p / "build.ncl").read_text(encoding="utf-8", errors="replace")
        for dep in set(IMPORT_RE.findall(src)):
            if dep in pkgs and dep != p:
                importers[dep].add(p)

    name_refs = {}  # pkg -> sorted list of non-package .ncl files naming it
    for f in sorted(root.rglob("*.ncl")):
        rel = f.relative_to(root)
        if rel.parts[0] in ("packages",) or ".git" in rel.parts:
            continue
        src = f.read_text(encoding="utf-8", errors="replace")
        for s in set(STRING_RE.findall(src)):
            if s in pkgs:
                name_refs.setdefault(s, []).append(str(rel))
    return pkgs, importers, name_refs


def transitive_dependents(pkg, importers):
    seen, stack = set(), [pkg]
    while stack:
        for d in importers.get(stack.pop(), ()):
            if d not in seen:
                seen.add(d)
                stack.append(d)
    seen.discard(pkg)  # a bootstrap cycle can reach back to the package itself
    return seen


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--packages-file", required=True)
    ap.add_argument("--root", default=".")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    changed = [
        line.strip()
        for line in Path(args.packages_file).read_text().splitlines()
        if line.strip()
    ]
    pkgs, importers, name_refs = load_graph(root)

    rows = []
    all_true_leaves = True
    for p in changed:
        if p not in pkgs:
            rows.append((p, "removed / not a package", "—", "n/a"))
            continue
        direct = sorted(importers[p])
        refs = name_refs.get(p, [])
        if not direct and not refs:
            rows.append((p, "**TRUE LEAF**", "—", "itself only"))
        elif not direct:
            all_true_leaves = False
            rows.append(
                (p, "leaf, referenced by", ", ".join(f"`{r}`" for r in refs[:3]), "stack/profile sessions")
            )
        else:
            all_true_leaves = False
            trans = transitive_dependents(p, importers)
            shown = ", ".join(f"`{d}`" for d in direct[:5]) + (" …" if len(direct) > 5 else "")
            rows.append(
                (p, f"{len(direct)} direct / {len(trans)} transitive", shown, f"{len(trans)} packages rebuild")
            )

    verdict = "ALL-TRUE-LEAVES" if (all_true_leaves and changed) else "HAS-DEPENDENTS"
    lines = [
        "## Blast radius",
        "",
        "_Report-only. \"If this update is wrong, what breaks?\" — computed from recipe",
        "imports plus stack/profile name references, no network._",
        "",
        "| package | dependents | direct importers | blast radius |",
        "|---|---|---|---|",
    ]
    for r in rows:
        lines.append("| `%s` | %s | %s | %s |" % r)
    lines += ["", f"`blast-radius: {verdict}`"]

    out = "\n".join(lines) + "\n"
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
