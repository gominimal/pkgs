#!/usr/bin/env python3
"""Tests for ci_scope.decide against this checkout's real package graph.

Each case also runs `old_decide`, the previous shell logic in ci.yml (touched
directories only), and asserts it gets the case wrong. That negative control
keeps every case honest: a case the old logic already handled would prove
nothing about the fix.

Run: python3 -I .github/scripts/test_ci_scope.py
"""

import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blast_radius_report import load_graph, transitive_dependents  # noqa: E402
from ci_scope import decide  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
UNLIMITED = 10**6


def old_decide(records):
    """The pre-review ci.yml scope step, transliterated."""
    files = [r["filename"] for r in records]
    code = [f for f in files if not re.search(r"(^|/)[^/]*\.md$|^legal/", f)]
    pkgs = sorted({m.group(1) for f in code if (m := re.match(r"^packages/([^/]*)/", f))})
    stacks = sorted({m.group(1) for f in code if (m := re.match(r"^stacks/([^/]*)/", f))})
    if [f for f in code if not re.match(r"^(packages|stacks)/", f)]:
        return "full", [], []
    if not pkgs and not stacks:
        return "none", [], []
    return "scoped", pkgs, stacks


def rec(filename, status="modified", previous=None):
    r = {"filename": filename, "status": status}
    if previous:
        r["previous_filename"] = previous
    return r


def files_referencing(needle):
    out = set()
    for f in (ROOT / "packages").rglob("*.ncl"):
        if needle in f.read_text(encoding="utf-8", errors="replace"):
            out.add(f.relative_to(ROOT / "packages").parts[0])
    return out


class Graph:
    pkgs, importers, name_refs = load_graph(ROOT)


def leaves(n):
    """n packages nothing imports and no stack names, for the cheap cases."""
    names = sorted(
        p for p in Graph.pkgs if not Graph.importers[p] and not Graph.name_refs.get(p)
    )
    assert len(names) >= n
    return names[:n]


class Scope(unittest.TestCase):
    def check(self, records, changed_files=None, max_scoped=None):
        if changed_files is None:
            changed_files = len(records)
        kw = {} if max_scoped is None else {"max_scoped": max_scoped}
        return decide(records, changed_files, ROOT, **kw)

    def test_gcc_change_reaches_every_subsetof_gcc_caller(self):
        callers = files_referencing("subsetOf gcc")
        self.assertGreater(len(callers), 100)
        records = [rec("packages/gcc/build.ncl")]
        mode, pkgs, _, _ = self.check(records, max_scoped=UNLIMITED)
        self.assertEqual(mode, "scoped")
        self.assertLessEqual(callers - {"gcc"}, set(pkgs))
        # At the real limit that is far too many: the full check runs.
        self.assertEqual(self.check(records)[0], "full")
        # Negative control: the old logic checked gcc alone.
        self.assertEqual(old_decide(records), ("scoped", ["gcc"], []))

    def test_shared_helper_reaches_its_importers(self):
        importers = files_referencing('"../hex0/amd64-ladder.ncl"')
        self.assertGreaterEqual(len(importers), 40)
        # The edge itself, not just reachability: most importers also reach
        # hex0 through the stage0 chain, which would hide a regex that only
        # matches build.ncl imports.
        self.assertLessEqual(importers - {"hex0"}, Graph.importers["hex0"])
        records = [rec("packages/hex0/amd64-ladder.ncl")]
        mode, pkgs, _, _ = self.check(records, max_scoped=UNLIMITED)
        self.assertLessEqual(importers, set(pkgs) | {"hex0"})
        self.assertEqual(self.check(records)[0], "full")
        self.assertEqual(old_decide(records), ("scoped", ["hex0"], []))

    def test_helper_imported_by_a_helper(self):
        # jdk-21 imports jdk/cve-2026-111943.ncl, which imports
        # ca-certificates/cve-2026-111943.ncl.
        records = [rec("packages/ca-certificates/cve-2026-111943.ncl")]
        mode, pkgs, _, _ = self.check(records)
        self.assertEqual(mode, "scoped")
        self.assertIn("jdk-21", pkgs)
        self.assertNotIn("jdk-21", old_decide(records)[1])

    def test_rename_across_packages_checks_both(self):
        a, b = leaves(2)
        records = [rec(f"packages/{b}/fix.patch", "renamed", previous=f"packages/{a}/fix.patch")]
        mode, pkgs, _, _ = self.check(records)
        self.assertEqual((mode, pkgs), ("scoped", sorted([a, b])))
        self.assertEqual(old_decide(records), ("scoped", [b], []))

    def test_rename_to_prose_is_not_prose(self):
        stack = sorted(p.parent.name for p in (ROOT / "stacks").glob("*/stack.ncl"))[0]
        records = [rec(f"stacks/{stack}/NOTES.md", "renamed", previous=f"stacks/{stack}/stack.ncl")]
        mode, _, stacks, _ = self.check(records)
        self.assertEqual(mode, "scoped")
        self.assertIn(stack, stacks)
        self.assertEqual(old_decide(records)[0], "none")

    def test_prose_only_checks_nothing(self):
        (a,) = leaves(1)
        records = [rec("README.md"), rec(f"packages/{a}/README.md"), rec("legal/x.txt")]
        self.assertEqual(self.check(records)[0], "none")
        self.assertEqual(old_decide(records)[0], "none")  # unchanged behaviour

    def test_truncated_file_list_runs_everything(self):
        (a,) = leaves(1)
        records = [rec(f"packages/{a}/build.ncl")]
        self.assertEqual(self.check(records, changed_files=3001)[0], "full")
        self.assertEqual(old_decide(records)[0], "scoped")

    def test_removed_package_runs_everything(self):
        records = [rec("packages/no-such-package-936/build.ncl", "removed")]
        self.assertEqual(self.check(records)[0], "full")
        self.assertEqual(old_decide(records), ("scoped", ["no-such-package-936"], []))

    def test_loose_file_under_packages_runs_everything(self):
        records = [rec("packages/common.ncl", "added")]
        self.assertEqual(self.check(records)[0], "full")
        self.assertEqual(old_decide(records)[0], "none")

    def test_stack_naming_a_changed_package_is_checked(self):
        for p in sorted(Graph.pkgs):
            refs = [r for r in Graph.name_refs.get(p, ()) if r.startswith("stacks/")]
            if refs and len(transitive_dependents(p, Graph.importers)) <= 5:
                break
        else:
            self.skipTest("no low-fan-out package is named by a stack")
        stack = refs[0].split("/")[1]
        records = [rec(f"packages/{p}/build.ncl")]
        mode, _, stacks, _ = self.check(records)
        self.assertEqual(mode, "scoped")
        self.assertIn(stack, stacks)
        self.assertEqual(old_decide(records), ("scoped", [p], []))

    def test_leaf_change_stays_small(self):
        # The point of scoping: a leaf package checks itself and nothing else.
        (a,) = leaves(1)
        self.assertEqual(self.check([rec(f"packages/{a}/build.ncl")])[:3], ("scoped", [a], []))


if __name__ == "__main__":
    unittest.main(verbosity=2)
