#!/usr/bin/env python3
"""Unit tests for ruby_flavor_guard.py. Run: python3 -m unittest test_ruby_flavor_guard"""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ruby_flavor_guard as g  # noqa: E402


def pkg(name, runtime=(), build=(), collection=False):
    return {
        "name": name,
        "is_collection": collection,
        "runtime_deps": [{"type": "package", "name": d} for d in runtime],
        "build_deps": [{"type": "package", "name": d} for d in build],
    }


BASE = [
    pkg("glibc"),
    pkg("ruby", runtime=["glibc"]),
    pkg("ruby-3.3", runtime=["glibc"]),
    pkg("ruby-3.4", runtime=["glibc"]),
    pkg("ruby-lsp", runtime=["ruby"], build=["ruby"]),
]


def problems(catalog):
    by_name = {p["name"]: p for p in catalog}
    memo = {}
    return {p["name"]: g.check(p, by_name, memo) for p in catalog if g.check(p, by_name, memo)}


class Guard(unittest.TestCase):
    def test_catalog_on_one_flavor_passes(self):
        self.assertEqual(problems(BASE), {})

    def test_stack_with_two_rubies_fails(self):
        cat = BASE + [pkg("rails-dev", runtime=["ruby-3.4", "ruby-lsp"], collection=True)]
        got = problems(cat)
        self.assertIn("rails-dev", got)
        self.assertTrue(any("runtime closure holds 2 Ruby lines: ruby, ruby-3.4" in p for p in got["rails-dev"]))

    def test_package_on_a_versioned_line_fails_flavor(self):
        cat = BASE + [pkg("gem-tool", runtime=["ruby-3.4"])]
        got = problems(cat)
        self.assertTrue(any(p.startswith("flavor: runtime_deps uses `ruby-3.4`") for p in got["gem-tool"]))

    def test_transitive_two_rubies_in_build_closure_fails(self):
        cat = BASE + [
            pkg("helper", runtime=["ruby-3.3"]),
            pkg("app", build=["ruby-lsp", "helper"]),
        ]
        got = problems(cat)
        self.assertTrue(any("build closure holds 2 Ruby lines: ruby, ruby-3.3" in p for p in got["app"]))

    def test_subset_dep_counts_as_that_line(self):
        cat = BASE + [{
            "name": "mixed",
            "is_collection": True,
            "runtime_deps": [
                {"type": "subset_of", "package": "ruby-3.4", "outputs": ["libruby"]},
                {"type": "package", "name": "ruby-lsp"},
            ],
            "build_deps": [],
        }]
        self.assertIn("mixed", problems(cat))

    def test_allowlisted_package_skips_flavor_only(self):
        g.VERSIONED_ALLOWED["gem-tool"] = "test"
        try:
            got = problems(BASE + [pkg("gem-tool", runtime=["ruby-3.4"])])
            self.assertNotIn("gem-tool", got)
        finally:
            del g.VERSIONED_ALLOWED["gem-tool"]

    def test_unreadable_dump_is_unverified(self):
        with tempfile.TemporaryDirectory() as d:
            empty = os.path.join(d, "dump.json")
            with open(empty, "w") as f:
                json.dump([], f)
            self.assertEqual(g.run([empty]), 2)

    def test_run_exits_1_on_violation(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "dump.json")
            with open(path, "w") as f:
                json.dump(BASE + [pkg("x", runtime=["ruby-3.4", "ruby-lsp"], collection=True)], f)
            self.assertEqual(g.run([path]), 1)


if __name__ == "__main__":
    unittest.main()
