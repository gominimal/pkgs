#!/usr/bin/env python3
"""Unit tests for gcc_runtime_guard.py. Run: python3 -m unittest test_gcc_runtime_guard"""

import io
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gcc_runtime_guard as g  # noqa: E402

HEAD = """let { subsetOf, BuildSpec, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let gcc = import "../gcc/build.ncl" in
let gcc-runtime = import "../gcc-runtime/build.ncl" in
let gcc-arm-none-eabi = import "../gcc-arm-none-eabi/build.ncl" in
let glibc = import "../glibc/build.ncl" in
"""


def recipe(runtime: str, build: str = "gcc,", extra: str = "") -> str:
    return HEAD + f"""{{
  name = "x",
  build_deps = [
    {build}
  ],
  runtime_deps = [
    {runtime}
  ],
{extra}
}} | BuildSpec
"""


def rules(text):
    return [rule for _, rule, _ in g.scan_text(text)[1]]


# The 9 forms the migration replaced, plus aliases the guard must also see.
VIOLATIONS = {
    "one-line subset": recipe('glibc, subsetOf gcc ["libgcc"],'),
    "multi-line boost form": recipe(
        """subsetOf
      gcc
      (
        ["libgcc", "libstdcpp"]
        @ match {
          { arch = 'Amd64, .. } => ["libquadmath"],
          { arch = 'Arm64, .. } => [],
        } target
      ),"""
    ),
    "whole gcc": recipe("glibc,\n    gcc,"),
    "whole gcc with trailing comment": recipe("gcc, # TODO, weird"),
    "whole gcc last, no comma": recipe("glibc,\n    gcc"),
    "renamed binding": recipe("cc,").replace(
        'let gcc = import "../gcc/build.ncl" in', 'let cc = import "../gcc/build.ncl" in'
    ),
    "inline import": recipe('subsetOf (import "../gcc/build.ncl") ["libgcc"],'),
    "breaker runtime_deps": recipe(
        "glibc,",
        extra="""  replace_on_cycle = {
    name = "x (prebuilt)",
    runtime_deps = [subsetOf gcc ["libgcc"]],
  } | BuildSpec,""",
    ),
    "whole gcc-runtime": recipe("glibc,\n    gcc-runtime,"),
    "array concatenated with an arch match": recipe(
        "glibc,\n  ] @ match { { arch = 'Amd64, .. } => [gcc], { arch = 'Arm64, .. } => [] } target @ [\n    glibc,"
    ),
}

CLEAN = {
    "gcc-runtime subset": recipe('glibc, subsetOf gcc-runtime ["libgcc", "libstdcpp"],'),
    "gcc-runtime multi-line subset": recipe(
        """subsetOf
      gcc-runtime
      (["libgcc"] @ match { { arch = 'Amd64, .. } => ["libquadmath"], { arch = 'Arm64, .. } => [] } target),"""
    ),
    "gcc in build_deps only": recipe("glibc,", build='gcc, subsetOf gcc ["libgcc"],'),
    "gcc in test_deps": recipe(
        "glibc,",
        extra="""  tests = { t = { test_deps = [gcc, subsetOf gcc ["libs"]], cmds = [] } },""",
    ),
    "gcc-arm-none-eabi": recipe("gcc-arm-none-eabi,"),
    "comment": recipe('glibc, # not `subsetOf gcc ["libgcc"]`, and not gcc'),
    "string": recipe('glibc,', extra='  cmd = "gcc -o x x.c; subsetOf gcc",'),
    "multiline string": recipe('glibc,', extra='  cmd = m%"\n    subsetOf gcc ["x"]\n    gcc,\n  "%,'),
    "field access": recipe("glibc,", extra="  version = gcc.version,"),
}


class ScanText(unittest.TestCase):
    def test_negative_control_every_violation_is_caught(self):
        for label, text in VIOLATIONS.items():
            with self.subTest(label):
                self.assertTrue(rules(text), f"guard missed: {label}")

    def test_clean_forms_pass(self):
        for label, text in CLEAN.items():
            with self.subTest(label):
                self.assertEqual(rules(text), [], label)

    def test_rule_names(self):
        self.assertEqual(rules(VIOLATIONS["one-line subset"]), ["subset"])
        self.assertEqual(rules(VIOLATIONS["multi-line boost form"]), ["subset"])
        self.assertEqual(rules(VIOLATIONS["whole gcc"]), ["whole-gcc"])
        self.assertEqual(rules(VIOLATIONS["inline import"]), ["inline-import"])
        self.assertEqual(rules(VIOLATIONS["whole gcc-runtime"]), ["whole-gcc-runtime"])

    def test_line_numbers_point_at_the_dep(self):
        text = VIOLATIONS["one-line subset"]
        (line, _, _), = g.scan_text(text)[1]
        self.assertIn("subsetOf gcc", text.splitlines()[line - 1])

    def test_counts_runtime_fields(self):
        self.assertEqual(g.scan_text(VIOLATIONS["breaker runtime_deps"])[0], 2)


class Repo(unittest.TestCase):
    def tree(self, files):
        d = tempfile.mkdtemp()
        for rel, text in files.items():
            p = os.path.join(d, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8") as f:
                f.write(text)
        return d

    def run_main(self, root, min_fields=1):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = g.main([root, "--min-fields", str(min_fields)])
        return code, out.getvalue() + err.getvalue()

    def base(self):
        return {
            "packages/toolchain/build.ncl": recipe("glibc,\n    gcc,"),
            "packages/zoxide/build.ncl": recipe('glibc, subsetOf gcc-runtime ["libgcc"],'),
            # gcc itself is never checked
            "packages/gcc/build.ncl": recipe("glibc,\n    gcc,"),
        }

    def test_clean_tree_passes(self):
        code, out = self.run_main(self.tree(self.base()))
        self.assertEqual(code, 0, out)
        self.assertIn("PASS", out)

    def test_negative_control_subset_fails(self):
        files = self.base()
        files["packages/atuin/build.ncl"] = recipe('glibc, subsetOf gcc ["libgcc"],')
        code, out = self.run_main(self.tree(files))
        self.assertEqual(code, 1, out)
        self.assertIn("packages/atuin/build.ncl", out)

    def test_whole_gcc_outside_allowlist_fails(self):
        files = self.base()
        files["packages/uv/build.ncl"] = recipe("glibc,\n    gcc, # TODO, weird")
        code, out = self.run_main(self.tree(files))
        self.assertEqual(code, 1, out)
        self.assertIn("whole-gcc", out)

    def test_helper_file_in_package_dir_is_scanned(self):
        files = self.base()
        files["packages/llvm/versioned.ncl"] = recipe('subsetOf gcc ["libgcc", "libstdcpp"],')
        code, out = self.run_main(self.tree(files))
        self.assertEqual(code, 1, out)
        self.assertIn("packages/llvm/versioned.ncl", out)

    def test_stale_allowlist_entry_fails(self):
        files = self.base()
        files["packages/toolchain/build.ncl"] = recipe("glibc,")
        code, out = self.run_main(self.tree(files))
        self.assertEqual(code, 1, out)
        self.assertIn("stale-allowlist", out)

    PIN_A = 'url = "gs://minimal-bootstrap/gen-13/sha256/aa/gcc-x86_64.tar.zst",\n        sha256 = "' + "a" * 64 + '",'
    PIN_B = 'url = "gs://minimal-bootstrap/gen-16/sha256/bb/gcc-x86_64.tar.zst",\n        sha256 = "' + "b" * 64 + '",'

    def breaker(self, pin):
        return recipe("glibc,") + "\nreplace_on_cycle = { build_deps = [ {\n        " + pin + "\n      } ] }\n"

    def test_breaker_pins_matching_gcc_pass(self):
        files = self.base()
        files["packages/gcc/build.ncl"] = self.breaker(self.PIN_A)
        files["packages/gcc-runtime/build.ncl"] = self.breaker(self.PIN_A)
        files["packages/gcc-runtime/stage.sh"] = files["packages/gcc-runtime-fortran/stage.sh"] = "x\n"
        code, out = self.run_main(self.tree(files))
        self.assertEqual(code, 0, out)

    def test_negative_control_breaker_pins_drift_fails(self):
        files = self.base()
        files["packages/gcc/build.ncl"] = self.breaker(self.PIN_B)
        files["packages/gcc-runtime/build.ncl"] = self.breaker(self.PIN_A)
        code, out = self.run_main(self.tree(files))
        self.assertEqual(code, 1, out)
        self.assertIn("breaker-pins", out)
        self.assertIn("gen-16", out)

    def test_breaker_pins_unreadable_fails(self):
        files = self.base()
        files["packages/gcc/build.ncl"] = self.breaker(self.PIN_A)
        files["packages/gcc-runtime/build.ncl"] = recipe("glibc,")
        code, out = self.run_main(self.tree(files))
        self.assertEqual(code, 1, out)
        self.assertIn("could not read", out)

    def with_stage(self, a="x() { :; }\n", b=None):
        files = self.base()
        files["packages/gcc-runtime/build.ncl"] = recipe("glibc,")
        files["packages/gcc-runtime/stage.sh"] = a
        files["packages/gcc-runtime-fortran/stage.sh"] = a if b is None else b
        return files

    def test_stage_helpers_identical_pass(self):
        code, out = self.run_main(self.tree(self.with_stage()))
        self.assertNotIn("stage-helper", out)

    def test_negative_control_stage_helpers_differ_fails(self):
        code, out = self.run_main(self.tree(self.with_stage(b="x() { :; }\n# edited\n")))
        self.assertEqual(code, 1, out)
        self.assertIn("stage-helper", out)

    def test_stage_helper_missing_fails(self):
        files = self.with_stage()
        del files["packages/gcc-runtime-fortran/stage.sh"]
        code, out = self.run_main(self.tree(files))
        self.assertEqual(code, 1, out)
        self.assertIn("stage-helper: missing", out)

    def closure_tree(self, gmp_runtime="glibc,", gmp_extra=""):
        files = self.with_stage()
        files["packages/gcc-runtime/build.ncl"] = self.breaker(self.PIN_A)
        gcc = recipe("glibc,", build="gmp,").replace(
            'let glibc = import "../glibc/build.ncl" in',
            'let glibc = import "../glibc/build.ncl" in\nlet gmp = import "../gmp/build.ncl" in',
        )
        breaker = "\nreplace_on_cycle = { build_deps = [ {\n        " + self.PIN_A + "\n      } ] }\n"
        files["packages/gcc/build.ncl"] = gcc + breaker
        files["packages/gmp/build.ncl"] = recipe(gmp_runtime, build="m4,", extra=gmp_extra)
        return files

    def test_gcc_closure_without_gcc_runtime_passes(self):
        code, out = self.run_main(self.tree(self.closure_tree()))
        self.assertEqual(code, 0, out)

    def test_negative_control_gcc_closure_reaching_gcc_runtime_fails(self):
        files = self.closure_tree(gmp_runtime='glibc, subsetOf gcc-runtime ["libstdcpp"],')
        code, out = self.run_main(self.tree(files))
        self.assertEqual(code, 1, out)
        self.assertIn("gcc-closure", out)
        self.assertIn("gcc -> gmp -> gcc-runtime", out)

    def test_gcc_closure_ignores_tests_breakers_and_comments(self):
        extra = """  replace_on_cycle = { runtime_deps = [subsetOf gcc-runtime ["libgcc"]] },
  tests = { t = { test_deps = [gcc-runtime], cmds = [] } },"""
        files = self.closure_tree(gmp_runtime="glibc, # not gcc-runtime", gmp_extra=extra)
        code, out = self.run_main(self.tree(files))
        self.assertNotIn("gcc-closure", out)

    def test_gcc_closure_follows_inline_imports(self):
        files = self.closure_tree(gmp_runtime='glibc, (import "../gcc-runtime-fortran/build.ncl"),')
        files["packages/gcc-runtime-fortran/build.ncl"] = recipe("glibc,")
        code, out = self.run_main(self.tree(files))
        self.assertIn("gcc -> gmp -> gcc-runtime-fortran", out)

    def test_unverified_without_packages(self):
        code, _ = self.run_main(tempfile.mkdtemp())
        self.assertEqual(code, 2)

    def test_unverified_when_too_few_fields(self):
        code, _ = self.run_main(self.tree(self.base()), min_fields=100)
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
