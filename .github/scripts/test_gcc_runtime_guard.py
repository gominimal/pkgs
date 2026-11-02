#!/usr/bin/env python3
"""Unit tests for gcc_runtime_guard.py. Run: python3 -m unittest test_gcc_runtime_guard"""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gcc_runtime_guard as g  # noqa: E402


def pkg(name, runtime=(), build=(), subsets=()):
    return {
        "name": name,
        "runtime_deps": [{"type": "package", "name": d} for d in runtime]
        + [{"type": "subset_of", "package": p, "outputs": list(o)} for p, o in subsets],
        "build_deps": [{"type": "package", "name": d} for d in build],
    }


# The shape on the branch: gcc carries the compiler closure, consumers take gcc-libs.
BASE = [
    pkg("glibc"),
    pkg("linux_headers"),
    pkg("gcc-libs", runtime=["glibc"], build=["gcc"]),
    pkg("gmp", runtime=["glibc"], subsets=[("gcc-libs", ["libgcc", "libstdcpp"])]),
    pkg("binutils", runtime=["glibc"], subsets=[("gcc-libs", ["libgcc", "libstdcpp"])]),
    pkg("gcc", runtime=["binutils", "glibc", "linux_headers", "gmp"], build=["gcc"]),
    pkg("toolchain", runtime=["binutils", "gcc", "glibc", "linux_headers"]),
    pkg("coreutils", runtime=["glibc", "gmp"], build=["toolchain"]),
    pkg("hex0", build=["coreutils"]),
]


def problems(catalog):
    by_name = {p["name"]: p for p in catalog}
    memo = {}
    tools = g.host_tools(catalog)
    out = {}
    for p in catalog:
        got = g.check(p, by_name, memo, tools)
        if got:
            out[p["name"]] = got
    return out


class Guard(unittest.TestCase):
    def test_catalog_on_gcc_libs_passes(self):
        self.assertEqual(problems(BASE), {})

    def test_subset_of_gcc_fails(self):
        # Negative control: the shape every consumer had before gcc-libs.
        cat = BASE + [pkg("ripgrep", runtime=["glibc"], subsets=[("gcc", ["libgcc"])])]
        got = problems(cat)
        self.assertIn("ripgrep", got)
        self.assertTrue(any(p.startswith("slice: runtime_deps takes a subset of gcc") for p in got["ripgrep"]))

    def test_whole_gcc_at_runtime_fails(self):
        got = problems(BASE + [pkg("tool", runtime=["gcc"])])
        self.assertTrue(any(p.startswith("slice: runtime_deps takes gcc;") for p in got["tool"]))

    def test_host_tool_reaching_binutils_fails(self):
        # gmp back on a slice of gcc: coreutils (a ladder host tool) now reaches binutils.
        cat = [p for p in BASE if p["name"] != "gmp"] + [
            pkg("gmp", runtime=["glibc"], subsets=[("gcc", ["libgcc", "libstdcpp"])]),
        ]
        got = problems(cat)
        self.assertIn("gmp", got)  # rule 1
        self.assertTrue(any("host: ladder host tool's runtime closure reaches binutils, gcc, linux_headers" in p
                            for p in got["coreutils"]))

    def test_closure_through_a_cycle_is_complete(self):
        # gcc <-> gmp is a runtime cycle. Every host tool behind gmp must see binutils, whichever
        # tool is walked first (a memo of a half-open node used to hide it from gawk-bootstrap).
        cat = [p for p in BASE if p["name"] != "gmp"] + [
            pkg("gmp", runtime=["glibc"], subsets=[("gcc", ["libgcc"])]),
            pkg("mpfr", runtime=["glibc", "gmp"]),
            pkg("gawk-bootstrap", runtime=["glibc", "mpfr"]),
        ]
        got = problems(cat)
        for tool in ("coreutils", "gawk-bootstrap"):
            self.assertTrue(any(p.startswith("host:") for p in got.get(tool, [])), tool)

    def test_rung_build_deps_count_as_host_tools(self):
        cat = BASE + [
            pkg("helper", runtime=["toolchain"]),
            pkg("stage0-musl-1.2.5", build=["helper", "stage0-gcc-4.0.4"]),
            pkg("stage0-gcc-4.0.4"),
        ]
        got = problems(cat)
        self.assertTrue(any(p.startswith("host:") for p in got["helper"]))
        self.assertNotIn("stage0-gcc-4.0.4", got)

    def test_allowlisted_package_skips_slice_only(self):
        got = problems(BASE + [pkg("kani", runtime=["gcc"])])
        self.assertNotIn("kani", got)

    def test_dump_without_gcc_libs_is_unverified(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "dump.json")
            with open(path, "w") as f:
                json.dump([pkg("glibc")], f)
            self.assertEqual(g.run([path]), 2)

    def test_empty_dump_is_unverified(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "dump.json")
            with open(path, "w") as f:
                json.dump([], f)
            self.assertEqual(g.run([path]), 2)

    def test_run_exits_1_on_violation(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "dump.json")
            with open(path, "w") as f:
                json.dump(BASE + [pkg("x", subsets=[("gcc", ["libgcc"])])], f)
            self.assertEqual(g.run([path]), 1)


if __name__ == "__main__":
    unittest.main()
