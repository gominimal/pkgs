#!/usr/bin/env python3
"""Unit tests for llvm_collision_guard.py. Run: python3 -m unittest test_llvm_collision_guard"""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import llvm_collision_guard as g  # noqa: E402


def pkg(name, runtime=(), build=(), globs=(), collection=False):
    return {
        "name": name,
        "is_collection": collection,
        "runtime_deps": [{"type": "package", "name": d} for d in runtime],
        "build_deps": [{"type": "package", "name": d} for d in build],
        "outputs": {f"o{i}": {"type": "binary", "value": {"glob": gl}} for i, gl in enumerate(globs)},
    }


def versioned(n, globs=None):
    return pkg(
        f"llvm-{n}",
        runtime=["glibc"],
        build=["llvm-bootstrap"],
        globs=globs or [f"usr/lib/llvm-{n}/bin/*", f"usr/lib/llvm-{n}/lib/**"],
    )


BASE = [
    pkg("glibc", globs=["usr/lib/libc.so*"]),
    pkg("llvm-bootstrap", runtime=["glibc"], globs=["usr/bin/*", "usr/lib/clang/*/**"]),
    pkg("llvm", runtime=["glibc"], build=["llvm-bootstrap"], globs=["usr/bin/*", "usr/include/llvm*/**"]),
    versioned(22),
    versioned(23),
    pkg("rust", runtime=["llvm"], build=["llvm"]),
]


def problems(catalog):
    by_name = {p["name"]: p for p in catalog}
    providers = frozenset(p["name"] for p in catalog if g.is_provider(p))
    memo = {}
    out = {}
    for p in catalog:
        got = g.check(p, by_name, memo, providers)
        if got:
            out[p["name"]] = got
    return out


class Guard(unittest.TestCase):
    def test_catalog_passes(self):
        self.assertEqual(problems(BASE), {})

    def test_prefixed_next_to_unprefixed_is_allowed(self):
        cat = BASE + [pkg("zig", runtime=["llvm", "llvm-22"], build=["llvm", "llvm-22"])]
        self.assertNotIn("zig", problems(cat))

    def test_two_prefixed_lines_are_allowed(self):
        cat = BASE + [pkg("both", runtime=["llvm-22", "llvm-23"], collection=True)]
        self.assertNotIn("both", problems(cat))

    def test_two_unprefixed_in_runtime_closure_fails(self):
        cat = BASE + [pkg("dev", runtime=["llvm", "llvm-bootstrap"], collection=True)]
        got = problems(cat)
        self.assertTrue(any(
            "runtime closure holds 2 unprefixed LLVM providers: llvm, llvm-bootstrap" in p for p in got["dev"]
        ))

    def test_transitive_two_unprefixed_in_build_closure_fails(self):
        cat = BASE + [
            pkg("helper", runtime=["llvm-bootstrap"]),
            pkg("app", build=["rust", "helper"]),
        ]
        got = problems(cat)
        self.assertTrue(any("build closure holds 2 unprefixed LLVM providers" in p for p in got["app"]))

    def test_versioned_line_escaping_its_prefix_fails_prefix_and_counts_as_provider(self):
        bad = versioned(24, globs=["usr/lib/llvm-24/bin/*", "usr/bin/*"])
        cat = BASE + [bad, pkg("app", runtime=["llvm", "llvm-24"])]
        got = problems(cat)
        self.assertTrue(any(p.startswith("prefix: outputs outside usr/lib/llvm-24/: usr/bin/*") for p in got["llvm-24"]))
        self.assertTrue(any("llvm, llvm-24" in p for p in got["app"]))

    def test_unnamed_copy_detected_by_its_output_paths(self):
        cat = BASE + [
            pkg("clang-prebuilt", globs=["usr/bin/clang*", "usr/lib/clang/*/**"]),
            pkg("app", runtime=["llvm", "clang-prebuilt"]),
        ]
        got = problems(cat)
        self.assertTrue(any("clang-prebuilt, llvm" in p for p in got["app"]))

    def test_unrelated_usr_globs_are_not_providers(self):
        for globs in (["usr/bin/*"], ["usr/lib/**"], ["usr/include/**"], ["usr/lib/llvm-22/bin/*"]):
            self.assertFalse(g.is_provider(pkg("coreutils", globs=globs)), globs)

    def test_subset_dep_counts_as_that_package(self):
        cat = BASE + [{
            "name": "mixed",
            "is_collection": True,
            "runtime_deps": [
                {"type": "subset_of", "package": "llvm-bootstrap", "outputs": ["bins"]},
                {"type": "package", "name": "llvm"},
            ],
            "build_deps": [],
            "outputs": {},
        }]
        self.assertIn("mixed", problems(cat))

    def test_empty_dump_is_unverified(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "dump.json")
            with open(path, "w") as f:
                json.dump([], f)
            self.assertEqual(g.run([path]), 2)

    def test_dump_without_llvm_is_unverified(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "dump.json")
            with open(path, "w") as f:
                json.dump([pkg("glibc")], f)
            self.assertEqual(g.run([path]), 2)

    def test_run_exits_0_on_clean_and_1_on_violation(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "dump.json")
            with open(path, "w") as f:
                json.dump(BASE, f)
            self.assertEqual(g.run([path]), 0)
            with open(path, "w") as f:
                json.dump(BASE + [pkg("x", runtime=["llvm", "llvm-bootstrap"], collection=True)], f)
            self.assertEqual(g.run([path]), 1)


if __name__ == "__main__":
    unittest.main()
