#!/usr/bin/env python3
"""Unit tests for source_hash_guard.py. Run: python3 -m unittest test_source_hash_guard

The incident cases run on real fixtures: `mip dump` output of the pkgs commits
named in fixtures/source_hash_guard/manifest.json. Set
SOURCE_HASH_GUARD_VERIFY_FIXTURES=1 (CI does, with mip on PATH and full
history) to re-dump each of those commits and check the fixtures still say
what the guard reads.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import source_hash_guard as g  # noqa: E402

FIXTURES = os.path.join(HERE, "fixtures", "source_hash_guard")
with open(os.path.join(FIXTURES, "manifest.json"), encoding="utf-8") as f:
    MANIFEST = json.load(f)


def fixture(commit: str, arch: str) -> dict:
    prefix = MANIFEST["commits"][commit]["file_prefix"]
    return g.load(os.path.join(FIXTURES, f"{prefix}-{arch}.json"))


def case(name: str) -> dict:
    return next(c for c in MANIFEST["cases"] if c["name"] == name)


def findings(name: str, diff: str = "") -> list[tuple[str, str, str]]:
    c = case(name)
    pairs = [(arch, fixture(c["base"], arch), fixture(c["head"], arch)) for arch in ("amd64", "arm64")]
    return [(level, arch, pkg) for level, arch, pkg, _ in g.check(pairs, g.allowed_from_diff(diff))]


def pkg(name, *srcs, version=None):
    return {
        "name": name,
        "attrs": {"upstream_version": {"value": version}} if version else {},
        "build_deps": [{"type": "source", "from": {"type": "web", "url": u, "sha256": s}} for u, s in srcs]
        + [{"type": "package", "name": "base"}],
    }


A = "a" * 64
B = "b" * 64


class RealIncidents(unittest.TestCase):
    def test_every_case_matches_its_recorded_expectation(self):
        for c in MANIFEST["cases"]:
            with self.subTest(case=c["name"]):
                self.assertEqual(sorted(map(tuple, c["expect"])), sorted(findings(c["name"])))

    def test_pkgs1003_stale_chromedriver_fails_both_arches(self):
        # the PR's first commit: the browser bump moved chromedriver-bin's
        # urls through interpolation, its build.ncl untouched
        self.assertEqual(findings("pkgs1003-stale"),
                         [("error", "amd64", "chromedriver-bin"), ("error", "arm64", "chromedriver-bin")])

    def test_pkgs1003_fixed_passes(self):
        # negative control: the same PR after 950d0f85 re-pinned both hashes
        self.assertEqual(findings("pkgs1003-fixed"), [])

    def test_pkgs402_version_bump_that_left_the_url_fails(self):
        self.assertEqual(findings("pkgs402-stale-url"), [("error", "amd64", "sqlite"), ("error", "arm64", "sqlite")])

    def test_pkgs511_url_correction_needs_the_marker(self):
        self.assertEqual({lvl for lvl, _, _ in findings("pkgs511-url-correction")}, {"error"})
        kept = "c917d7db16648ec95f714974ace5e5dcf46b7dc70e26600a0a102a3141125db0"
        diff = f"+  # source-hash-guard: allow {kept} sha256 was already 3.53.3's; this fixes the url\n"
        self.assertEqual({lvl for lvl, _, _ in findings("pkgs511-url-correction", diff)}, {"note"})

    def test_pkgs847_org_moves_are_relocations(self):
        self.assertTrue(findings("pkgs847-relocation"))
        self.assertEqual({lvl for lvl, _, _ in findings("pkgs847-relocation")}, {"note"})


class Rules(unittest.TestCase):
    def test_unchanged_catalog_is_clean(self):
        p = pkg("x", ("https://e.org/x-1.0.tar.gz", A))
        self.assertEqual(g.compare(p, p), [])

    def test_version_bump_with_new_sha_is_clean(self):
        self.assertEqual(g.compare(pkg("x", ("https://e.org/x-1.0.tar.gz", A)),
                                   pkg("x", ("https://e.org/x-1.1.tar.gz", B))), [])

    def test_version_bump_with_kept_sha_is_an_error(self):
        got = g.compare(pkg("x", ("https://e.org/x-1.0.tar.gz", A)), pkg("x", ("https://e.org/x-1.1.tar.gz", A)))
        self.assertEqual([lvl for lvl, _, _ in got], ["error"])
        self.assertEqual(got[0][1], A)

    def test_reordered_version_digits_with_kept_sha_is_an_error(self):
        # CodeRabbit on #1106: as bare digit sets, 1.2 and 2.1 are both {1, 2}
        for old, new in (("1.2", "2.1"), ("1.1.2", "1.2.1"), ("1_86_0", "1_0_86")):
            with self.subTest(old=old, new=new):
                got = g.compare(pkg("x", (f"https://e.org/x-{old}.tar.gz", A)),
                                pkg("x", (f"https://e.org/x-{new}.tar.gz", A)))
                self.assertEqual([lvl for lvl, _, _ in got], ["error"])

    def test_mirror_of_url_naming_the_version_twice_is_a_note(self):
        got = g.compare(pkg("x", ("https://github.com/o/x/releases/download/v1.2.3/x-1.2.3.tar.gz", A)),
                        pkg("x", ("gs://minimal-staging-archives/x-1.2.3.tar.gz", A)))
        self.assertEqual([lvl for lvl, _, _ in got], ["note"])

    def test_commit_archive_moved_with_kept_sha_is_an_error(self):
        old = "https://github.com/o/r/archive/1f2e3d4c5b6a79881f2e3d4c5b6a79881f2e3d4c.tar.gz"
        new = "https://github.com/o/r/archive/9a8b7c6d5e4f30219a8b7c6d5e4f30219a8b7c6d.tar.gz"
        self.assertEqual([lvl for lvl, _, _ in g.compare(pkg("x", (old, A)), pkg("x", (new, A)))], ["error"])

    def test_mirror_move_with_kept_sha_is_a_note(self):
        got = g.compare(pkg("x", ("https://e.org/x-1.0.tar.gz", A)),
                        pkg("x", ("gs://minimal-staging-archives/x-1.0.tar.gz", A)))
        self.assertEqual([lvl for lvl, _, _ in got], ["note"])

    def test_sha_change_under_versioned_url_warns(self):
        got = g.compare(pkg("x", ("https://e.org/x-1.0.tar.gz", A)), pkg("x", ("https://e.org/x-1.0.tar.gz", B)))
        self.assertEqual([lvl for lvl, _, _ in got], ["warning"])
        self.assertEqual(got[0][1], B)

    def test_version_bump_that_keeps_a_versioned_url_is_an_error(self):
        got = g.compare(pkg("x", ("https://e.org/x-1.0.tar.gz", A), version="1.0"),
                        pkg("x", ("https://e.org/x-1.0.tar.gz", B), version="1.1"))
        self.assertEqual([(lvl, sha) for lvl, sha, _ in got], [("error", B)])

    def test_version_bump_under_unversioned_url_is_a_note(self):
        got = g.compare(pkg("x", ("https://e.org/latest/x.zip", A), version="1.0"),
                        pkg("x", ("https://e.org/latest/x.zip", B), version="1.1"))
        self.assertEqual([lvl for lvl, _, _ in got], ["note"])

    def test_sha_change_under_url_naming_upstream_version_warns(self):
        # a version with no dot (a date, a revision) is still a version
        got = g.compare(pkg("x", ("https://e.org/r1243/x.zip", A), version="1243"),
                        pkg("x", ("https://e.org/r1243/x.zip", B), version="1243"))
        self.assertEqual([lvl for lvl, _, _ in got], ["warning"])

    def test_sha_change_under_unversioned_url_is_a_note(self):
        got = g.compare(pkg("x", ("https://e.org/latest/x.zip", A)), pkg("x", ("https://e.org/latest/x.zip", B)))
        self.assertEqual([lvl for lvl, _, _ in got], ["note"])

    def test_sha_case_does_not_matter(self):
        p = pkg("x", ("https://e.org/x-1.0.tar.gz", A))
        q = pkg("x", ("https://e.org/x-1.1.tar.gz", A.upper()))
        self.assertEqual([lvl for lvl, _, _ in g.compare(p, q)], ["error"])

    def test_new_and_removed_packages_are_ignored(self):
        base = {"x": pkg("x", ("https://e.org/x-1.0.tar.gz", A))}
        head = {"y": pkg("y", ("https://e.org/y-2.0.tar.gz", A))}
        self.assertEqual(g.check([("amd64", base, head)], {}), [])

    def test_one_stale_source_among_several_is_found(self):
        base = pkg("x", ("https://e.org/x-1.0.tar.gz", A), ("https://e.org/x-data-1.0.tar.gz", B))
        head = pkg("x", ("https://e.org/x-1.1.tar.gz", "c" * 64), ("https://e.org/x-data-1.1.tar.gz", B))
        got = g.compare(base, head)
        self.assertEqual([(lvl, sha) for lvl, sha, _ in got], [("error", B)])


class OptOut(unittest.TestCase):
    STALE = ({"x": pkg("x", ("https://e.org/x-1.0.tar.gz", A))}, {"x": pkg("x", ("https://e.org/x-1.1.tar.gz", A))})

    def levels(self, diff):
        base, head = self.STALE
        return [lvl for lvl, _, _, _ in g.check([("amd64", base, head)], g.allowed_from_diff(diff))]

    def test_added_marker_with_reason_allows(self):
        self.assertEqual(self.levels(f"+  # source-hash-guard: allow {A} same bytes, new mirror path\n"), ["note"])

    def test_marker_on_a_context_or_removed_line_does_not_allow(self):
        # a marker left in the recipe by an earlier change must not excuse this one
        self.assertEqual(self.levels(f"   # source-hash-guard: allow {A} old reason\n"), ["error"])
        self.assertEqual(self.levels(f"-  # source-hash-guard: allow {A} old reason\n"), ["error"])

    def test_marker_needs_a_reason(self):
        self.assertEqual(self.levels(f"+  # source-hash-guard: allow {A}\n"), ["error"])

    def test_marker_for_another_sha_does_not_allow(self):
        self.assertEqual(self.levels(f"+  # source-hash-guard: allow {B} wrong hash\n"), ["error"])


class Run(unittest.TestCase):
    def write(self, d, name, data):
        path = os.path.join(d, name)
        with open(path, "w") as f:
            json.dump(data, f)
        return path

    def test_exit_codes(self):
        with tempfile.TemporaryDirectory() as d:
            base = self.write(d, "base.json", [pkg("x", ("https://e.org/x-1.0.tar.gz", A))])
            stale = self.write(d, "stale.json", [pkg("x", ("https://e.org/x-1.1.tar.gz", A))])
            fine = self.write(d, "fine.json", [pkg("x", ("https://e.org/x-1.1.tar.gz", B))])
            empty = self.write(d, "empty.json", [])
            self.assertEqual(g.run([(base, stale)], None), 1)
            self.assertEqual(g.run([(base, fine)], None), 0)
            self.assertEqual(g.run([(base, empty)], None), 2)
            self.assertEqual(g.run([(empty, fine)], None), 2)
            self.assertEqual(g.run([(base, os.path.join(d, "missing.json"))], None), 2)
            self.assertEqual(g.run([(base, fine)], os.path.join(d, "missing.diff")), 2)

    def test_warning_does_not_fail(self):
        with tempfile.TemporaryDirectory() as d:
            base = self.write(d, "base.json", [pkg("x", ("https://e.org/x-1.0.tar.gz", A))])
            reroll = self.write(d, "reroll.json", [pkg("x", ("https://e.org/x-1.0.tar.gz", B))])
            self.assertEqual(g.run([(base, reroll)], None), 0)


@unittest.skipUnless(os.environ.get("SOURCE_HASH_GUARD_VERIFY_FIXTURES") == "1",
                     "set SOURCE_HASH_GUARD_VERIFY_FIXTURES=1 to re-dump the fixture commits")
class FixtureProvenance(unittest.TestCase):
    """Each fixture still equals a fresh dump of its recorded commit, in every
    field the guard reads. Once enabled this FAILS, never skips, when mip or a
    commit is missing: an unverifiable fixture is not a verified one."""

    def test_fixtures_match_a_fresh_dump(self):
        root = subprocess.run(["git", "-C", HERE, "rev-parse", "--show-toplevel"],
                              capture_output=True, text=True, check=True).stdout.strip()
        for commit, meta in MANIFEST["commits"].items():
            have = subprocess.run(["git", "-C", root, "cat-file", "-e", f"{commit}^{{commit}}"], capture_output=True)
            if have.returncode != 0 and meta.get("pr"):
                subprocess.run(["git", "-C", root, "fetch", "--quiet", "https://github.com/gominimal/pkgs",
                                f"refs/pull/{meta['pr']}/head"], capture_output=True, check=True)
            with tempfile.TemporaryDirectory() as wt:
                subprocess.run(["git", "-C", root, "worktree", "add", "--detach", wt, commit],
                               capture_output=True, check=True)
                try:
                    for arch in ("amd64", "arm64"):
                        r = subprocess.run(["mip", "dump", "-p", "--format", "json", "--arch", arch],
                                           cwd=wt, capture_output=True, check=True)
                        fresh = {p["name"]: p for p in json.loads(r.stdout)}
                        recorded = fixture(commit, arch)
                        self.assertEqual(sorted(recorded), sorted(meta["packages"]))
                        for name, p in recorded.items():
                            with self.subTest(commit=commit[:12], arch=arch, package=name):
                                self.assertEqual((g.sources(p), g.upstream_version(p)),
                                                 (g.sources(fresh[name]), g.upstream_version(fresh[name])))
                finally:
                    subprocess.run(["git", "-C", root, "worktree", "remove", "--force", wt], capture_output=True)


if __name__ == "__main__":
    unittest.main()
