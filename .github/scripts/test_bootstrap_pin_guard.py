#!/usr/bin/env python3
"""Unit tests for bootstrap_pin_guard.py. Run: python3 -m unittest test_bootstrap_pin_guard"""

import json
import os
import sys
import tempfile
import unittest
import urllib.error
from contextlib import redirect_stdout
from io import StringIO
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bootstrap_pin_guard as g  # noqa: E402

A = "a" * 64  # gcc, amd64
B = "b" * 64  # gcc, arm64
C = "c" * 64  # published in gen-2 only
GEN1 = f"{A}  sha256/{A}/gcc-x86_64.tar.zst\n{B}  sha256/{B}/gcc-aarch64.tar.zst\n"
GEN2 = f"{C}  sha256/{C}/gcc-x86_64.tar.zst\n"


def url(gen, sha, name):
    return f"gs://minimal-bootstrap/{gen}/sha256/{sha}/{name}"


def source(u, sha):
    return {"type": "source", "from": {"url": u, "sha256": sha, "extract": True}}


class Guard(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        # run() prints findings as workflow commands under Actions.
        env = mock.patch.dict(os.environ)
        env.start()
        self.addCleanup(env.stop)
        os.environ.pop("GITHUB_ACTIONS", None)
        self.mdir = os.path.join(self.tmp.name, "manifests")
        os.mkdir(self.mdir)
        for gen, text in (("gen-1", GEN1), ("gen-2", GEN2)):
            with open(os.path.join(self.mdir, f"{gen}.txt"), "w", encoding="utf-8") as f:
                f.write(text)
        self.m = g.Manifests(self.mdir)

    def dump(self, pkgs, name="dump.json"):
        path = os.path.join(self.tmp.name, name)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(pkgs, f)
        return path

    def tree(self, text, name="build.ncl"):
        root = os.path.join(self.tmp.name, "packages")
        os.makedirs(os.path.join(root, "gcc"), exist_ok=True)
        with open(os.path.join(root, "gcc", name), "w", encoding="utf-8") as f:
            f.write(text)
        return root

    def test_published_pin_passes(self):
        self.assertEqual(g.check_pin(url("gen-1", A, "gcc-x86_64.tar.zst"), A, "amd64", self.m), [])
        self.assertEqual(g.check_pin(url("gen-1", B, "gcc-aarch64.tar.zst"), B, "arm64", self.m), [])

    def test_url_and_sha256_disagree(self):
        got = g.check_pin(url("gen-1", A, "gcc-x86_64.tar.zst"), B, "amd64", self.m)
        self.assertEqual(len(got), 1)
        self.assertTrue(got[0].startswith("sha256:"))

    def test_sha256_field_missing(self):
        got = g.check_pin(url("gen-1", A, "gcc-x86_64.tar.zst"), None, "amd64", self.m)
        self.assertTrue(any(p.startswith("sha256:") for p in got))

    def test_object_from_another_generation(self):
        got = g.check_pin(url("gen-1", C, "gcc-x86_64.tar.zst"), C, "amd64", self.m)
        self.assertEqual(len(got), 1)
        self.assertTrue(got[0].startswith("manifest:"))

    def test_right_sha256_wrong_file_name(self):
        got = g.check_pin(url("gen-1", A, "gcc-15-x86_64.tar.zst"), A, "amd64", self.m)
        self.assertTrue(got and got[0].startswith("manifest:"))

    def test_other_arch_object(self):
        got = g.check_pin(url("gen-1", B, "gcc-aarch64.tar.zst"), B, "amd64", self.m)
        self.assertEqual(len(got), 1)
        self.assertTrue(got[0].startswith("arch:"))

    def test_malformed_urls(self):
        for bad in (
            "gs://minimal-bootstrap/gen-1/gcc-x86_64.tar.zst",
            f"gs://minimal-bootstrap/gen-1/sha256/{A[:63]}/gcc-x86_64.tar.zst",
            f"gs://minimal-bootstrap/latest/sha256/{A}/gcc-x86_64.tar.zst",
            f"gs://minimal-bootstrap/gen-1/sha256/{A.upper()}/gcc-x86_64.tar.zst",
        ):
            got = g.check_pin(bad, A, "amd64", self.m)
            self.assertTrue(got and got[0].startswith("shape:"), bad)

    def run_quiet(self, *args):
        out = StringIO()
        with redirect_stdout(out):
            code = g.run(*args)
        return code, out.getvalue()

    def test_unpublished_generation_is_a_bad_pin(self):
        got = g.check_pin(url("gen-9", A, "gcc-x86_64.tar.zst"), A, "amd64", self.m)
        self.assertEqual(len(got), 1)
        self.assertTrue(got[0].startswith("manifest: gen-9 is not published"), got)

    def test_empty_manifest_is_unverified(self):
        with open(os.path.join(self.mdir, "gen-3.txt"), "w", encoding="utf-8") as f:
            f.write("<html>not a manifest</html>\n")
        with self.assertRaises(g.Unverified):
            self.m.objects("gen-3")

    def test_parse_manifest_requires_matching_path(self):
        self.assertEqual(g.parse_manifest(f"{A}  sha256/{B}/gcc-x86_64.tar.zst\n"), set())
        self.assertEqual(g.parse_manifest(GEN1), {(A, "gcc-x86_64.tar.zst"), (B, "gcc-aarch64.tar.zst")})

    def test_pins_found_outside_build_deps(self):
        pkg = {
            "name": "glibc",
            "build_deps": [source("gs://minimal-staging-archives/glibc.tar.xz", "d" * 64)],
            "replace_on_cycle": {"prebuilt": {"url": url("gen-1", A, "gcc-x86_64.tar.zst"), "sha256": A}},
        }
        self.assertEqual(g.pins(pkg), [(url("gen-1", A, "gcc-x86_64.tar.zst"), A)])

    def test_run_passes_on_a_good_catalog(self):
        amd = self.dump([{"name": "gcc", "build_deps": [source(url("gen-1", A, "gcc-x86_64.tar.zst"), A)]}], "amd.json")
        arm = self.dump([{"name": "gcc", "build_deps": [source(url("gen-1", B, "gcc-aarch64.tar.zst"), B)]}], "arm.json")
        self.assertEqual(g.run([("amd64", amd), ("arm64", arm)], [], self.mdir), 0)

    def test_run_fails_on_a_bad_pin(self):
        amd = self.dump([{"name": "gcc", "build_deps": [source(url("gen-1", A, "gcc-x86_64.tar.zst"), B)]}])
        self.assertEqual(g.run([("amd64", amd)], [], self.mdir), 1)

    def test_run_unverified_without_any_pin(self):
        amd = self.dump([{"name": "zlib", "build_deps": []}])
        self.assertEqual(g.run([("amd64", amd)], [], self.mdir), 2)

    def test_run_unverified_on_missing_or_empty_dump(self):
        self.assertEqual(g.run([("amd64", os.path.join(self.tmp.name, "absent.json"))], [], self.mdir), 2)
        self.assertEqual(g.run([("amd64", self.dump([]))], [], self.mdir), 2)

    def test_run_locates_an_unpublished_generation(self):
        amd = self.dump([{"name": "gcc", "build_deps": [source(url("gen-9", A, "gcc-x86_64.tar.zst"), A)]}])
        code, out = self.run_quiet([("amd64", amd)], [], self.mdir)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL amd64 gcc: manifest: gen-9 is not published", out)
        root = self.tree(f'url = "{url("gen-9", A, "gcc-x86_64.tar.zst")}",\n')
        code, out = self.run_quiet([], [root], self.mdir)
        self.assertEqual(code, 1, out)
        self.assertIn("build.ncl:1: manifest: gen-9 is not published", out)
        with mock.patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}):
            code, out = self.run_quiet([("amd64", amd)], [], self.mdir)
        self.assertEqual(code, 1, out)
        self.assertIn("::error title=bootstrap-pin-guard::amd64 gcc: manifest: gen-9 is not published", out)

    def test_bucket_404_is_unpublished_other_errors_unverified(self):
        m = g.Manifests()
        e404 = urllib.error.HTTPError("u", 404, "Not Found", {}, None)
        with mock.patch.object(g.urllib.request, "urlopen", side_effect=e404):
            self.assertIsNone(m.objects("gen-61"))
        for err in (urllib.error.HTTPError("u", 500, "boom", {}, None), urllib.error.URLError("dns")):
            with mock.patch.object(g.urllib.request, "urlopen", side_effect=err):
                with self.assertRaises(g.Unverified):
                    g.Manifests().objects("gen-1")

    def test_dump_without_pins_is_unverified_beside_a_good_tree(self):
        # The tree scan always finds literals; a dump that yields none (no
        # replace_on_cycle in the dump, a changed Source shape) must not hide.
        root = self.tree(f'url = "{url("gen-1", A, "gcc-x86_64.tar.zst")}",\n')
        amd = self.dump([{"name": "zlib", "build_deps": []}])
        code, out = self.run_quiet([("amd64", amd)], [root], self.mdir)
        self.assertEqual(code, 2, out)
        self.assertIn("no gs://minimal-bootstrap pin found in", out)
        # Negative control: the same tree with a dump that has a pin passes.
        good = self.dump([{"name": "gcc", "build_deps": [source(url("gen-1", A, "gcc-x86_64.tar.zst"), A)]}], "g.json")
        self.assertEqual(self.run_quiet([("amd64", good)], [root], self.mdir)[0], 0)

    def test_missing_tree_root_is_unverified_beside_a_good_dump(self):
        amd = self.dump([{"name": "gcc", "build_deps": [source(url("gen-1", A, "gcc-x86_64.tar.zst"), A)]}])
        self.tree(f'url = "{url("gen-1", A, "gcc-x86_64.tar.zst")}",\n')
        missing = os.path.join(self.tmp.name, "no-such-dir")
        code, out = self.run_quiet([("amd64", amd)], [os.path.join(self.tmp.name, "packages"), missing], self.mdir)
        self.assertEqual(code, 2, out)
        self.assertIn("no-such-dir", out)

    @unittest.skipIf(hasattr(os, "geteuid") and os.geteuid() == 0, "root reads any directory")
    def test_unlistable_subtree_is_unverified(self):
        root = self.tree(f'url = "{url("gen-1", A, "gcc-x86_64.tar.zst")}",\n')
        locked = os.path.join(root, "locked")
        os.mkdir(locked)
        os.chmod(locked, 0)
        self.addCleanup(os.chmod, locked, 0o700)
        with self.assertRaises(g.Unverified) as cm:
            g.check_tree([root], self.m)
        self.assertIn("locked", str(cm.exception))

    def test_single_quoted_literal(self):
        root = self.tree(f"URL='{url('gen-1', A, 'gcc-x86_64.tar.zst')}'\n", name="fetch.sh")
        self.assertEqual(g.check_tree([root], self.m), (1, []))

    def test_tree_literal_checked_and_located(self):
        root = self.tree(f'url = "{url("gen-1", A, "gcc-x86_64.tar.zst")}",\nurl = "{url("gen-2", A, "gcc-x86_64.tar.zst")}",\n')
        seen, bad = g.check_tree([root], self.m)
        self.assertEqual(seen, 2)
        self.assertEqual(len(bad), 1)
        self.assertIn("build.ncl:2: manifest:", bad[0])

    def test_tree_skips_interpolated_and_unscanned(self):
        root = self.tree('url = "gs://minimal-bootstrap/gen-1/sha256/%{sha}/gcc-x86_64.tar.zst",\n')
        self.tree("gs://minimal-bootstrap/gen-1/nonsense\n", name="notes.md")
        self.assertEqual(g.check_tree([root], self.m), (0, []))


if __name__ == "__main__":
    unittest.main()
