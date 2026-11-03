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

    # Each of these passed 6b09baf0 with "1 preload(s) checked, 0 violation(s)",
    # and a later child process saw LD_PRELOAD (checked by running the script).

    def test_an_assignment_is_not_a_command(self):
        self.assert_rejected(
            {"build.sh": f"LD_PRELOAD={LIB} FOO=1\ntrue; export LD_PRELOAD\nmake\n"}, "not used as"
        )

    def test_a_quoted_assignment_is_not_a_command(self):
        self.assert_rejected({"build.sh": f"LD_PRELOAD={LIB} CFLAGS=\"-O2 -g\"\nmake\n"}, "not used as")

    def test_an_export_after_an_operator_is_rejected(self):
        self.assert_rejected(
            {"build.sh": f"LD_PRELOAD={LIB} make\ntrue && export LD_PRELOAD\n"},
            "exported in a file that preloads",
        )

    def test_any_other_ld_preload_mention_is_rejected(self):
        self.assert_rejected(
            {"build.sh": f"LD_PRELOAD={LIB} make\neval \"LD_PRELOAD=$P; export LD_PRELOAD\"\n"},
            "in a file that preloads",
        )

    def test_a_second_mention_on_the_prefix_line_is_rejected(self):
        # Reported as an export since the 2026-11-03 widening of EXPORTED
        # (it was "not used as" when only line-start exports matched).
        self.assert_rejected({"build.sh": f"LD_PRELOAD={LIB} make; export LD_PRELOAD\n"}, "exported")

    def test_a_special_builtin_is_not_a_command(self):
        # Under sh (dash) or bash --posix the assignment outlives `:` and is exported.
        for cmd in (":", ". ./env.sh", "eval true", "exec >log", "set -e"):
            with self.subTest(cmd=cmd):
                self.tearDown()
                self.setUp()
                self.assert_rejected({"build.sh": f"#!/bin/sh\nLD_PRELOAD={LIB} {cmd}\nmake\n"}, "not used as")

    def test_a_redirection_alone_is_not_a_command(self):
        self.assert_rejected({"build.sh": f"LD_PRELOAD={LIB} >build.log\nmake\n"}, "not used as")

    def test_assignments_then_a_command_pass(self):
        # Negative control for the assignment rule: still one scoped command.
        self.pkg("e", {"build.sh": f"LD_PRELOAD={LIB} CFLAGS=\"-O2 -g\" FOO=1 make -j4\nunset LD_PRELOAD\n"})
        self.assertEqual(g.check(self.root), (1, []))

    # Norrie's re-review of e064ffc (2026-11-03): each passed with
    # "1 preload(s) checked, 0 violation(s)" and left LD_PRELOAD set for
    # later commands in bash and dash.
    NOT_AT_COMMAND_START = (
        f"cd build && export LD_PRELOAD={LIB} make",
        f"if true; then export LD_PRELOAD={LIB} PATH; fi",
        f"command export LD_PRELOAD={LIB} make",
        f"builtin export LD_PRELOAD={LIB} make",
        f"declare -g -x LD_PRELOAD={LIB} make",
        f"f() {{ local -x LD_PRELOAD={LIB} cargo build; }}",
        f"readonly LD_PRELOAD={LIB} make",
    )

    def test_a_declaration_anywhere_on_the_line_is_rejected(self):
        for line in self.NOT_AT_COMMAND_START:
            with self.subTest(line=line):
                self.tearDown()
                self.setUp()
                self.pkg("bad", {"build.sh": f"#!/bin/sh\n{line}\nmake\n"})
                uses, errors = g.check(self.root)
                self.assertEqual(uses, 0, errors)
                self.assertTrue(any("exported" in e for e in errors), errors)

    def test_the_path_as_an_argument_is_not_a_prefix(self):
        # make exports command-line variables into every recipe it runs.
        self.assert_rejected({"build.sh": f"make LD_PRELOAD={LIB} cc\n"}, "not used as")

    def test_a_prefix_after_an_operator_or_keyword_passes(self):
        # Negative control for the command-start rule: each is still one
        # scoped command.
        for line in (
            f"cd build && LD_PRELOAD={LIB} make -j4",
            f"if true; then LD_PRELOAD={LIB} make; fi",
            f"( cd build; LD_PRELOAD={LIB} make )",
            f"true || env LD_PRELOAD={LIB} make",
            f"for d in a b; do LD_PRELOAD={LIB} make -C \"$d\"; done",
        ):
            with self.subTest(line=line):
                self.tearDown()
                self.setUp()
                self.pkg("ok", {"build.sh": f"#!/bin/sh\n{line}\n"})
                self.assertEqual(g.check(self.root), (1, []))

    def test_assignments_before_offline_cargo_pass(self):
        self.pkg(
            "f",
            {"build.sh": "cargo fetch --locked\n" + f"LD_PRELOAD={LIB} RUSTFLAGS=-Cx cargo " + "build --frozen\n"},
            ncl=NETWORKED_NCL,
        )
        self.assertEqual(g.check(self.root), (1, []))

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
