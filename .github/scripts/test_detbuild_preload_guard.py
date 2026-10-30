#!/usr/bin/env python3
"""Unit tests for detbuild_preload_guard.py. Run: python3 -m unittest test_detbuild_preload_guard"""

import os
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import detbuild_preload_guard as g  # noqa: E402

LIB = "/usr/lib/minimal/libdetbuild.so"
OFFLINE_NCL = 'let x = 1 in { name = "p" }\n'
NETWORKED_NCL = 'let x = 1 in { name = "p", attrs = { needs = { internet = { reason = "fetch" } } } }\n'


class Guard(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        (self.root / "packages" / "detbuild").mkdir(parents=True)
        # detbuild itself names the library freely and is never scanned.
        (self.root / "packages" / "detbuild" / "build.ncl").write_text(f'env = {{ LD_PRELOAD = "{LIB}" }}\n')

    def tearDown(self):
        self.tmp.cleanup()

    def pkg(self, name, files, ncl=OFFLINE_NCL):
        d = self.root / "packages" / name
        d.mkdir(parents=True, exist_ok=True)
        (d / "build.ncl").write_text(ncl)
        for rel, text in files.items():
            p = d / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            if isinstance(text, bytes):
                p.write_bytes(text)
            else:
                p.write_text(text)

    # ── passing shapes ──────────────────────────────────────────────

    def test_prefix_on_one_command_passes_and_is_counted(self):
        self.pkg("a", {"build.sh": f"#!/bin/sh\nLD_PRELOAD={LIB} make -j4\n"})
        self.assertEqual(g.check(self.root), (1, []))

    def test_networked_package_with_offline_cargo_passes(self):
        self.pkg(
            "b",
            {"build.sh": "cargo fetch --locked\n" + f"LD_PRELOAD={LIB} cargo " + "build --frozen --release\n"},
            ncl=NETWORKED_NCL,
        )
        self.assertEqual(g.check(self.root), (1, []))

    def test_a_continued_cargo_command_passes(self):
        # Norrie on #884: the backslash-continued form AGENTS.md's example grows into.
        self.pkg(
            "d",
            {"build.sh": "cargo fetch --locked\n" + f"LD_PRELOAD={LIB} \\\n  cargo " + "build --frozen --release\n"},
            ncl=NETWORKED_NCL,
        )
        self.assertEqual(g.check(self.root), (1, []))

    def test_comments_and_binaries_are_ignored(self):
        self.pkg("c", {"build.sh": f"# export LD_PRELOAD={LIB}\n", "blob.bin": b"\0\0" + LIB.encode()})
        self.assertEqual(g.check(self.root), (0, []))

    # ── rejected shapes (msample/mitodrummer's list on #884) ────────

    def assert_rejected(self, files, needle, ncl=OFFLINE_NCL):
        self.pkg("bad", files, ncl=ncl)
        _, errors = g.check(self.root)
        self.assertTrue(any(needle in e for e in errors), errors)

    def test_export_is_rejected(self):
        self.assert_rejected({"build.sh": f"export LD_PRELOAD={LIB}\nmake\n"}, "exported")

    def test_declare_x_is_rejected(self):
        self.assert_rejected({"build.sh": f"declare -x LD_PRELOAD={LIB}\n"}, "exported")

    def test_bare_assignment_is_rejected(self):
        self.assert_rejected({"build.sh": f"LD_PRELOAD={LIB}\nmake\n"}, "not used as")

    def test_trailing_comment_is_a_bare_assignment(self):
        # Norrie on #884: this passed with "1 preload(s) checked, 0 violation(s)"
        # and preloaded `make` and every later command.
        self.assert_rejected(
            {"build.sh": f"LD_PRELOAD={LIB}  # pin entropy for the build\nexport LD_PRELOAD\nmake\n"},
            "not used as",
        )

    def test_export_without_the_path_is_rejected_in_a_preloading_file(self):
        self.assert_rejected(
            {"build.sh": f"LD_PRELOAD={LIB}  # pin entropy for the build\nexport LD_PRELOAD\nmake\n"},
            "exported in a file that preloads",
        )

    def test_an_operator_after_the_path_is_rejected(self):
        self.assert_rejected({"build.sh": f"LD_PRELOAD={LIB}; make\n"}, "not used as")

    def test_ncl_mention_is_rejected(self):
        self.assert_rejected({"extra.ncl": f'env = {{ LD_PRELOAD = "{LIB}" }}\n'}, "in a .ncl file")

    def test_networked_non_cargo_command_is_rejected(self):
        self.assert_rejected({"build.sh": f"LD_PRELOAD={LIB} make\n"}, "needs.internet", ncl=NETWORKED_NCL)

    # ── the widened scan ────────────────────────────────────────────

    def test_bash_python_and_extensionless_helpers_are_scanned(self):
        for rel in ("helper.bash", "gen.py", "scripts/configure-wrapper"):
            with self.subTest(rel=rel):
                self.tearDown()
                self.setUp()
                self.assert_rejected({rel: f"export LD_PRELOAD={LIB}\n"}, "exported")

    def test_a_stack_naming_the_library_is_rejected(self):
        d = self.root / "stacks" / "dev"
        d.mkdir(parents=True)
        (d / "stack.ncl").write_text(f'env = {{ LD_PRELOAD = "{LIB}" }}\n')
        _, errors = g.check(self.root)
        self.assertTrue(any("in a stack" in e for e in errors), errors)

    def test_main_fails_on_a_violation(self):
        self.pkg("a", {"build.sh": f"LD_PRELOAD={LIB} make\n"})
        self.pkg("z", {"build.sh": f"export LD_PRELOAD={LIB}\n"})
        argv = sys.argv
        try:
            sys.argv = ["detbuild_preload_guard.py", str(self.root)]
            self.assertEqual(g.main(), 1)
        finally:
            sys.argv = argv


if __name__ == "__main__":
    unittest.main()
