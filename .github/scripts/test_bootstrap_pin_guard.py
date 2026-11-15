#!/usr/bin/env python3
"""Unit tests for bootstrap_pin_guard.py. Run: python3 -m unittest test_bootstrap_pin_guard"""

import json
import os
import sys
import tempfile
import unittest

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

    def test_unpublished_generation_is_unverified(self):
        with self.assertRaises(g.Unverified):
            g.check_pin(url("gen-9", A, "gcc-x86_64.tar.zst"), A, "amd64", self.m)

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

    def test_run_unverified_on_unpublished_generation(self):
        amd = self.dump([{"name": "gcc", "build_deps": [source(url("gen-9", A, "gcc-x86_64.tar.zst"), A)]}])
        self.assertEqual(g.run([("amd64", amd)], [], self.mdir), 2)

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
