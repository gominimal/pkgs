#!/usr/bin/env python3
"""Unit tests for libgcc_dlopen_guard.py. Run: python3 -m unittest test_libgcc_dlopen_guard"""

import io
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import libgcc_dlopen_guard as g  # noqa: E402

HEAD = """let { subsetOf, BuildSpec, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let gcc = import "../gcc/build.ncl" in
let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let is_arm = false in
"""


def recipe(runtime: str, build: str = "gcc,", extra: str = "", head: str = HEAD) -> str:
    return head + f"""{{
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


LIBGCC = 'subsetOf gcc-runtime ["libgcc"],'


def importers(*pkgs, symbols=("pthread_exit",)):
    out = []
    for p in pkgs:
        out.append(f'[importers."{p}"]\nsymbols = {list(symbols)!r}\narches = ["amd64", "arm64"]\n'.replace("'", '"'))
        out.append(f'elfs = ["usr/lib/lib{p}.so.1"]\nelf_count = 1\n')
    return "\n".join(out)


class Repo(unittest.TestCase):
    def tree(self, files, listed=("app",)):
        d = tempfile.mkdtemp()
        files = dict(files)
        files.setdefault(".github/scripts/libgcc_dlopen_importers.toml", importers(*listed))
        for name in ("glibc", "gcc", "gcc-runtime"):
            files.setdefault(f"packages/{name}/build.ncl", recipe("glibc,") if name != "glibc" else recipe(""))
        for rel, text in files.items():
            p = os.path.join(d, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8") as f:
                f.write(text)
        return d

    def run_main(self, root, min_fields=1, min_importers=1):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = g.main([root, "--min-fields", str(min_fields), "--min-importers", str(min_importers)])
        return code, out.getvalue() + err.getvalue()

    def assertPass(self, files, listed=("app",)):
        code, out = self.run_main(self.tree(files, listed))
        self.assertEqual(code, 0, out)
        self.assertIn("PASS", out)

    def assertFail(self, files, listed=("app",), pkg="app"):
        code, out = self.run_main(self.tree(files, listed))
        self.assertEqual(code, 1, out)
        self.assertIn(f"`{pkg}`", out)
        return out

    # --- covered -------------------------------------------------------------

    def test_direct_libgcc_passes(self):
        self.assertPass({"packages/app/build.ncl": recipe("glibc, " + LIBGCC)})

    def test_libgcc_with_other_outputs_passes(self):
        self.assertPass({"packages/app/build.ncl": recipe('glibc, subsetOf gcc-runtime ["libstdcpp", "libgcc"],')})

    def test_multi_line_match_subset_passes(self):
        rt = """subsetOf
      gcc-runtime
      (
        ["libgcc"]
        @ match {
          { arch = 'Amd64, .. } => ["libquadmath"],
          { arch = 'Arm64, .. } => [],
        } target
      ),"""
        self.assertPass({"packages/app/build.ncl": recipe(rt)})

    def test_transitive_runtime_dep_passes(self):
        self.assertPass(
            {
                "packages/app/build.ncl": recipe("glibc, openssl,"),
                "packages/openssl/build.ncl": recipe("glibc, " + LIBGCC),
            }
        )

    def test_through_a_subset_parents_runtime_deps_passes(self):
        # A subset dep still brings the parent's runtime_deps into the closure.
        self.assertPass(
            {
                "packages/app/build.ncl": recipe('glibc, subsetOf openssl ["libs"],'),
                "packages/openssl/build.ncl": recipe("glibc, " + LIBGCC),
            }
        )

    def test_whole_toolchain_ships_gcc(self):
        self.assertPass(
            {
                "packages/app/build.ncl": recipe("glibc, toolchain,"),
                "packages/toolchain/build.ncl": recipe("glibc,\n    gcc,"),
            }
        )

    def test_providers_cover_themselves(self):
        self.assertPass({}, listed=("gcc", "gcc-runtime"))

    def test_helper_runtime_deps_followed(self):
        head = HEAD + 'let llvm = (import "../llvm/versioned.ncl") "22.1.8" "abc" in\n'
        app = head + '{\n  name = "app",\n  runtime_deps = llvm.runtime_deps,\n} | BuildSpec\n'
        helper = HEAD + 'fun version sha => {\n  runtime_deps = [glibc, ' + LIBGCC + "],\n}\n"
        self.assertPass({"packages/app/build.ncl": app, "packages/llvm/versioned.ncl": helper})

    def test_unconditional_dep_beside_an_arch_branch_passes(self):
        rt = "glibc,\n  ] @ (if is_arm then [glibc] else [glibc]) @ [\n    " + LIBGCC
        self.assertPass({"packages/app/build.ncl": recipe(rt)})

    # --- negative controls: each must FAIL ----------------------------------

    def test_negative_control_no_libgcc_fails(self):
        out = self.assertFail({"packages/app/build.ncl": recipe("glibc,")})
        self.assertIn("pthread_exit", out)
        self.assertIn('subsetOf gcc-runtime ["libgcc"]', out)
        self.assertIn("packages/app/build.ncl", out)

    def test_negative_control_other_gcc_runtime_output_fails(self):
        self.assertFail({"packages/app/build.ncl": recipe('glibc, subsetOf gcc-runtime ["libstdcpp"],')})

    def test_negative_control_libgcc_only_in_build_deps_fails(self):
        self.assertFail({"packages/app/build.ncl": recipe("glibc,", build="gcc, " + LIBGCC)})

    def test_negative_control_libgcc_only_in_tests_fails(self):
        extra = "  tests = { t = { test_deps = [" + LIBGCC + "], runtime_deps = [" + LIBGCC + "], cmds = [] } },"
        self.assertFail({"packages/app/build.ncl": recipe("glibc,", extra=extra)})

    def test_negative_control_libgcc_only_in_breaker_fails(self):
        extra = '  replace_on_cycle = { name = "app (prebuilt)", runtime_deps = [' + LIBGCC + "] } | BuildSpec,"
        self.assertFail({"packages/app/build.ncl": recipe("glibc,", extra=extra)})

    def test_negative_control_libgcc_only_in_dep_build_deps_fails(self):
        self.assertFail(
            {
                "packages/app/build.ncl": recipe("glibc, openssl,"),
                "packages/openssl/build.ncl": recipe("glibc,", build="gcc, " + LIBGCC),
            }
        )

    def test_negative_control_libgcc_in_comment_or_string_fails(self):
        rt = 'glibc, # ' + LIBGCC
        extra = '  cmd = "subsetOf gcc-runtime [\\"libgcc\\"]",'
        self.assertFail({"packages/app/build.ncl": recipe(rt, extra=extra)})

    def test_negative_control_libgcc_on_one_arch_only_fails(self):
        # Fails closed: the guard cannot tell which arch lacks it.
        rt = "glibc,\n  ] @ (if is_arm then [" + LIBGCC + "] else []) @ [\n    glibc,"
        self.assertFail({"packages/app/build.ncl": recipe(rt)})

    def test_negative_control_libgcc_in_match_arm_fails(self):
        rt = "glibc,\n  ] @ match { { arch = 'Amd64, .. } => [" + LIBGCC + "], { arch = 'Arm64, .. } => [] } target @ [\n    glibc,"
        self.assertFail({"packages/app/build.ncl": recipe(rt)})

    def test_negative_control_field_access_is_not_a_dep(self):
        # `python.passthru` inside runtime_deps reads a field; it is not python.
        self.assertFail(
            {
                "packages/app/build.ncl": recipe("glibc,\n    python.passthru,"),
                "packages/python/build.ncl": recipe("glibc, " + LIBGCC),
            }
        )

    def test_negative_control_runtime_cycle_terminates_and_fails(self):
        self.assertFail(
            {
                "packages/app/build.ncl": recipe("glibc, openssl,"),
                "packages/openssl/build.ncl": recipe("glibc, python,"),
                "packages/python/build.ncl": recipe("glibc, openssl,"),
            }
        )

    def test_only_listed_packages_are_checked(self):
        self.assertPass({"packages/app/build.ncl": recipe("glibc, " + LIBGCC), "packages/other/build.ncl": recipe("glibc,")})

    def test_listed_package_without_recipe_fails(self):
        code, out = self.run_main(self.tree({"packages/app/build.ncl": recipe("glibc, " + LIBGCC)}, listed=("app", "gone")))
        self.assertEqual(code, 1, out)
        self.assertIn("packages/gone/build.ncl does not exist", out)

    def test_failure_message_names_symbols(self):
        files = {
            "packages/app/build.ncl": recipe("glibc,"),
            ".github/scripts/libgcc_dlopen_importers.toml": importers("app", symbols=("backtrace", "pthread_cancel")),
        }
        code, out = self.run_main(self.tree(files))
        self.assertEqual(code, 1, out)
        self.assertIn("backtrace, pthread_cancel", out)
        self.assertIn("usr/lib/libapp.so.1", out)

    # --- unverified ----------------------------------------------------------

    def test_unverified_without_packages(self):
        code, _ = self.run_main(tempfile.mkdtemp())
        self.assertEqual(code, 2)

    def test_unverified_without_data_file(self):
        d = self.tree({"packages/app/build.ncl": recipe("glibc,")})
        os.remove(os.path.join(d, ".github/scripts/libgcc_dlopen_importers.toml"))
        code, _ = self.run_main(d)
        self.assertEqual(code, 2)

    def test_unverified_when_data_file_is_near_empty(self):
        code, _ = self.run_main(self.tree({"packages/app/build.ncl": recipe("glibc,")}), min_importers=10)
        self.assertEqual(code, 2)

    def test_unverified_on_unknown_symbol(self):
        files = {
            "packages/app/build.ncl": recipe("glibc,"),
            ".github/scripts/libgcc_dlopen_importers.toml": importers("app", symbols=("dlopen",)),
        }
        code, _ = self.run_main(self.tree(files))
        self.assertEqual(code, 2)

    def test_unverified_when_too_few_fields(self):
        code, _ = self.run_main(self.tree({"packages/app/build.ncl": recipe("glibc, " + LIBGCC)}), min_fields=100)
        self.assertEqual(code, 2)


class RealTree(unittest.TestCase):
    """The shipped data file parses and lists enough importers."""

    def test_shipped_data_file_loads(self):
        root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
        data = os.path.join(root, ".github", "scripts", "libgcc_dlopen_importers.toml")
        imp = g.load_importers(data)
        self.assertGreaterEqual(len(imp), g.MIN_IMPORTERS)
        for pkg in imp:
            self.assertTrue(os.path.isfile(os.path.join(root, "packages", pkg, "build.ncl")), pkg)


if __name__ == "__main__":
    unittest.main()
