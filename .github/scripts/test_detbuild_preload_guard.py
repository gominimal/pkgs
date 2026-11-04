#!/usr/bin/env python3
"""Unit tests for detbuild_preload_guard.py. Run: python3 -m unittest test_detbuild_preload_guard"""

import contextlib
import io
import json
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
        # The catalog as `mip dump -p` gives it, one {name: entry} per arch.
        self.arches = [{}]
        self.dep("detbuild", runtime=["glibc"])
        self.dep("glibc")

    def tearDown(self):
        self.tmp.cleanup()

    def dep(self, name, build=(), runtime=(), internet=False, arch=None):
        """A catalog entry with no files of its own."""
        entry = {
            "name": name,
            "build_deps": [{"type": "package", "name": n} for n in build],
            "runtime_deps": [{"type": "package", "name": n} for n in runtime],
            "needs": {"internet": {"type": "map", "value": {}}} if internet else {},
        }
        for i, pkgs in enumerate(self.arches):
            if arch is None or arch == i:
                pkgs[name] = entry

    def check(self):
        return g.check(self.root, g.Catalog([list(pkgs.values()) for pkgs in self.arches]))

    def pkg(self, name, files, ncl=OFFLINE_NCL, build=("detbuild",), runtime=("glibc",)):
        d = self.root / "packages" / name
        d.mkdir(parents=True, exist_ok=True)
        (d / "build.ncl").write_text(ncl)
        self.dep(name, build=build, runtime=runtime, internet=ncl is NETWORKED_NCL)
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
        self.assertEqual(self.check(), (1, []))

    def test_networked_package_with_offline_cargo_passes(self):
        self.pkg(
            "b",
            {"build.sh": "cargo fetch --locked\n" + f"LD_PRELOAD={LIB} cargo " + "build --frozen --release\n"},
            ncl=NETWORKED_NCL,
        )
        self.assertEqual(self.check(), (1, []))

    def test_a_continued_cargo_command_passes(self):
        # The backslash-continued form AGENTS.md's example grows into.
        self.pkg(
            "d",
            {"build.sh": "cargo fetch --locked\n" + f"LD_PRELOAD={LIB} \\\n  cargo " + "build --frozen --release\n"},
            ncl=NETWORKED_NCL,
        )
        self.assertEqual(self.check(), (1, []))

    def test_comments_and_binaries_are_ignored(self):
        self.pkg("c", {"build.sh": f"# export LD_PRELOAD={LIB}\n", "blob.bin": b"\0\0" + LIB.encode()})
        self.assertEqual(self.check(), (0, []))

    # ── rejected shapes ─────────────────────────────────────────────

    def assert_rejected(self, files, needle, ncl=OFFLINE_NCL):
        self.pkg("bad", files, ncl=ncl)
        _, errors = self.check()
        self.assertTrue(any(needle in e for e in errors), errors)

    def test_export_is_rejected(self):
        self.assert_rejected({"build.sh": f"export LD_PRELOAD={LIB}\nmake\n"}, "exported")

    def test_declare_x_is_rejected(self):
        self.assert_rejected({"build.sh": f"declare -x LD_PRELOAD={LIB}\n"}, "exported")

    def test_bare_assignment_is_rejected(self):
        self.assert_rejected({"build.sh": f"LD_PRELOAD={LIB}\nmake\n"}, "not used as")

    def test_trailing_comment_is_a_bare_assignment(self):
        # A comment after the path leaves a bare assignment, which the
        # export carries into `make` and every later command.
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

    # Each of these leaves LD_PRELOAD set for a later child process.

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
        self.assertEqual(self.check(), (1, []))

    # Each names the path somewhere other than a command start, and leaves
    # LD_PRELOAD set for later commands in bash and dash.
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
                uses, errors = self.check()
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
                self.assertEqual(self.check(), (1, []))

    def test_assignments_before_offline_cargo_pass(self):
        self.pkg(
            "f",
            {"build.sh": "cargo fetch --locked\n" + f"LD_PRELOAD={LIB} RUSTFLAGS=-Cx cargo " + "build --frozen\n"},
            ncl=NETWORKED_NCL,
        )
        self.assertEqual(self.check(), (1, []))

    def test_an_unset_followed_by_a_reexport_is_rejected(self):
        self.assert_rejected(
            {
                "build.sh": "cargo fetch --locked\n"
                + f"LD_PRELOAD={LIB} cargo " + f"build --frozen; P={LIB}\n"
                + "unset LD_PRELOAD; LD_PRELOAD=$P; export LD_PRELOAD\ncurl https://example.invalid\n"
            },
            "exported in a file that preloads",
            ncl=NETWORKED_NCL,
        )

    def test_an_offline_flag_in_a_comment_does_not_count(self):
        self.assert_rejected(
            {"build.sh": f"LD_PRELOAD={LIB} cargo " + "build # --frozen\n"}, "must run offline", ncl=NETWORKED_NCL
        )

    def test_an_offline_flag_on_another_command_does_not_count(self):
        self.assert_rejected(
            {"build.sh": f"LD_PRELOAD={LIB} cargo " + "build; true --frozen\n"}, "must run offline", ncl=NETWORKED_NCL
        )

    def test_a_standalone_unset_and_a_commented_offline_cargo_pass(self):
        # Negative control for the two rules above.
        self.pkg(
            "g",
            {
                "build.sh": "cargo fetch --locked\n"
                + f"LD_PRELOAD={LIB} cargo " + "build --frozen --release  # pinned entropy\n"
                + "unset LD_PRELOAD  # done with the preload\n"
            },
            ncl=NETWORKED_NCL,
        )
        self.assertEqual(self.check(), (1, []))

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
        _, errors = self.check()
        self.assertTrue(any("in a stack" in e for e in errors), errors)

    def write_dump(self):
        path = self.root / "dump.json"
        path.write_text(json.dumps(list(self.arches[0].values())))
        return str(path)

    def test_main_fails_on_a_violation(self):
        self.pkg("a", {"build.sh": f"LD_PRELOAD={LIB} make\n"})
        self.pkg("z", {"build.sh": f"export LD_PRELOAD={LIB}\n"})
        self.assertEqual(g.main(["--dump", self.write_dump(), str(self.root)]), 1)

    def test_main_passes_a_clean_tree(self):
        # Negative control for the main() failures.
        self.pkg("a", {"build.sh": f"LD_PRELOAD={LIB} make\n"})
        self.assertEqual(g.main(["--dump", self.write_dump(), str(self.root)]), 0)

    def test_main_requires_a_catalog_dump(self):
        self.pkg("a", {"build.sh": f"LD_PRELOAD={LIB} make\n"})
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            g.main([str(self.root)])

    def test_main_rejects_a_dump_of_another_tree(self):
        self.pkg("a", {"build.sh": f"LD_PRELOAD={LIB} make\n"})
        del self.arches[0]["detbuild"]
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(g.main(["--dump", self.write_dump(), str(self.root)]), 1)

    # ── shell operators glued to a word ─────────────────────────────
    # Whitespace splitting read `:;` as one word, which is not `:`, so each
    # of these counted as a good preload. Each is a bare assignment followed
    # by more commands, and under sh or bash --posix the assignment before a
    # special builtin persists into all of them.

    GLUED = (
        f"LD_PRELOAD={LIB} :; make",
        f"LD_PRELOAD={LIB} set -e; make",
        f"LD_PRELOAD={LIB} eval; make",
        f"LD_PRELOAD={LIB} :&& make",
        f"LD_PRELOAD={LIB} :|| make",
        f"LD_PRELOAD={LIB} :& make",
        f"LD_PRELOAD={LIB} :|cat",
        f"LD_PRELOAD={LIB} FOO=1; make",
        f"LD_PRELOAD={LIB} FOO=1&& make",
        f"LD_PRELOAD={LIB} CFLAGS=\"-O2 -g\"; make",
        f"LD_PRELOAD={LIB} 2>log; make",
        f"LD_PRELOAD={LIB} >log; make",
    )

    def test_an_operator_glued_to_a_word_ends_the_command(self):
        for line in self.GLUED:
            with self.subTest(line=line):
                self.tearDown()
                self.setUp()
                self.pkg("bad", {"build.sh": f"#!/bin/sh\n{line}\n"})
                uses, errors = self.check()
                self.assertEqual(uses, 0, errors)
                self.assertTrue(any("not used as" in e for e in errors), errors)

    def test_a_glued_operator_after_a_real_command_passes(self):
        # Negative control: the preload is on `make` and ends at the operator.
        for line in (
            f"LD_PRELOAD={LIB} make; echo done",
            f"LD_PRELOAD={LIB} make&& echo done",
            f"LD_PRELOAD={LIB} make>build.log",
            f"LD_PRELOAD={LIB} 2>&1 make|tee build.log",
            f"LD_PRELOAD={LIB} FOO=1 make -j$(nproc)",
        ):
            with self.subTest(line=line):
                self.tearDown()
                self.setUp()
                self.pkg("ok", {"build.sh": f"#!/bin/sh\n{line}\n"})
                self.assertEqual(self.check(), (1, []))

    def test_an_offline_flag_after_a_glued_operator_does_not_count(self):
        self.assert_rejected(
            {"build.sh": f"LD_PRELOAD={LIB} cargo " + "build;true --frozen\n"}, "must run offline", ncl=NETWORKED_NCL
        )

    def test_a_command_named_by_expansion_is_rejected(self):
        self.assert_rejected({"build.sh": f"LD_PRELOAD={LIB} $BUILD\n"}, "not used as")

    def test_unbalanced_quotes_are_rejected(self):
        self.assert_rejected({"build.sh": f"LD_PRELOAD={LIB} make \"oops\n"}, "not used as")

    # ── the network comes from the build closure ────────────────────
    # The builder grants the network when the package or any package in its
    # sandbox closure declares needs.internet: its build_deps and
    # runtime_deps, plus their runtime_deps transitively.

    def test_a_build_dep_that_declares_internet_networks_the_build(self):
        # nushell's shape: no needs block of its own, `rust` in build_deps.
        self.dep("rust", runtime=["llvm"], internet=True)
        self.dep("llvm")
        self.pkg("nu", {"build.sh": f"LD_PRELOAD={LIB} make\n"}, build=("detbuild", "rust"))
        _, errors = self.check()
        self.assertTrue(any("through its build closure" in e for e in errors), errors)

    def test_offline_cargo_under_a_networked_build_dep_passes(self):
        # Negative control for the closure rule.
        self.dep("rust", internet=True)
        self.pkg(
            "nu",
            {"build.sh": "cargo fetch --locked\n" + f"LD_PRELOAD={LIB} cargo " + "build --frozen --release\n"},
            build=("detbuild", "rust"),
        )
        self.assertEqual(self.check(), (1, []))

    def test_a_runtime_dep_of_a_dep_networks_the_build(self):
        self.dep("git", runtime=["curl"])
        self.dep("curl", internet=True)
        self.pkg("p", {"build.sh": f"LD_PRELOAD={LIB} make\n"}, build=("detbuild", "git"))
        _, errors = self.check()
        self.assertTrue(any("through its build closure" in e for e in errors), errors)

    def test_a_own_runtime_dep_networks_the_build(self):
        self.dep("curl", internet=True)
        self.pkg("p", {"build.sh": f"LD_PRELOAD={LIB} make\n"}, runtime=("glibc", "curl"))
        _, errors = self.check()
        self.assertTrue(any("through its build closure" in e for e in errors), errors)

    def test_a_build_dep_of_a_dep_does_not_network_the_build(self):
        # Negative control: a dependency's own build_deps are not mounted, so
        # their needs do not reach this build (Transitives recurses with
        # include_build_deps = false).
        self.dep("curl", internet=True)
        self.dep("libfoo", build=["curl"])
        self.pkg("p", {"build.sh": f"LD_PRELOAD={LIB} make\n"}, build=("detbuild", "libfoo"))
        self.assertEqual(self.check(), (1, []))

    def test_networked_on_one_arch_is_networked(self):
        self.arches.append({k: v for k, v in self.arches[0].items()})
        self.dep("curl", arch=0)
        self.dep("curl", internet=True, arch=1)
        self.pkg("p", {"build.sh": f"LD_PRELOAD={LIB} make\n"}, build=("detbuild", "curl"))
        _, errors = self.check()
        self.assertTrue(any("through its build closure" in e for e in errors), errors)

    def test_a_package_on_one_arch_is_judged_on_that_arch(self):
        # Negative control for the two rules below: absent from an arch is
        # not unresolved there.
        self.arches.append({k: v for k, v in self.arches[0].items()})
        self.pkg("p", {"build.sh": f"LD_PRELOAD={LIB} make\n"})
        del self.arches[1]["p"]
        self.assertEqual(self.check(), (1, []))

    def test_an_unresolved_closure_counts_as_networked(self):
        self.pkg("p", {"build.sh": f"LD_PRELOAD={LIB} make\n"}, build=("detbuild", "missing"))
        _, errors = self.check()
        self.assertTrue(any("does not resolve" in e for e in errors), errors)

    def test_a_package_missing_from_the_catalog_counts_as_networked(self):
        self.pkg("p", {"build.sh": f"LD_PRELOAD={LIB} make\n"})
        del self.arches[0]["p"]
        _, errors = self.check()
        self.assertTrue(any("does not resolve" in e for e in errors), errors)

    def test_a_preloaded_cargo_must_be_offline_even_without_the_network(self):
        self.assert_rejected({"build.sh": f"LD_PRELOAD={LIB} cargo " + "build --locked --release\n"}, "must run offline")

    # ── the library must be in the build sandbox ────────────────────

    def test_a_preload_without_detbuild_in_build_deps_is_rejected(self):
        self.pkg("p", {"build.sh": f"LD_PRELOAD={LIB} make\n"}, build=())
        _, errors = self.check()
        self.assertTrue(any("does not list `detbuild`" in e for e in errors), errors)

    def test_detbuild_missing_on_one_arch_is_rejected(self):
        self.pkg("p", {"build.sh": f"LD_PRELOAD={LIB} make\n"})
        self.arches.append({k: v for k, v in self.arches[0].items()})
        self.dep("p", runtime=["glibc"], arch=1)
        _, errors = self.check()
        self.assertTrue(any("does not list `detbuild`" in e for e in errors), errors)


if __name__ == "__main__":
    unittest.main()
