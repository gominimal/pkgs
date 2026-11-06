#!/usr/bin/env python3
"""Keep libdetbuild preloads scoped to one offline build command.

packages/detbuild/libdetbuild.so replaces getrandom, getentropy, arc4random
and /dev/urandom reads with a fixed-seed stream. That is what makes a build
reproducible, and it also makes every key generated under the preload
predictable: a TLS handshake made under it uses guessable ephemeral keys. So a
preload must stay on the one command that needs it (AGENTS.md, "Preloading
detbuild"):

1. In a package's text files other than .ncl (shell scripts of any
   extension, extensionless helpers, Python), every non-comment line that mentions
   libdetbuild must be a command prefix, `LD_PRELOAD=<path> <command>` (or
   `env LD_PRELOAD=<path> <command>`), and what follows the path must be a
   command, not a `# comment` or a shell operator (`LD_PRELOAD=... # note` is a
   bare assignment). `export LD_PRELOAD=...`, `declare -x` and a bare
   `LD_PRELOAD=...` assignment are rejected: they reach every later command,
   including the ones that fetch. "A command" means a command word: further
   assignments are skipped (`LD_PRELOAD=... FOO=1` is still bare), a
   redirection alone is not one, and neither is a POSIX special builtin
   (`:`, `.`, `eval`, `export`, `set`, ...), because under sh or
   `bash --posix` an assignment before one persists and is exported
   (`LD_PRELOAD=... :` preloads everything after it). In a file that names
   libdetbuild, LD_PRELOAD may appear ONLY as that one checked prefix (or in
   an `unset LD_PRELOAD` alone on its line), so a later `export LD_PRELOAD`, wherever it sits on
   its line (`true && export LD_PRELOAD`), is rejected too. The prefix
   itself must sit where a command starts (line start, after `;` `&&` `||`
   `|` `(` `{` `!`, or `if`/`then`/`do`/...): `cd x && export
   LD_PRELOAD=<path> make`, `local -x LD_PRELOAD=<path> cargo` and `make
   LD_PRELOAD=<path> cc` name the path but are not prefixes.
   Backslash-continued lines are joined first, so a preloaded command may span
   lines. The words after the path are tokenized the way the shell splits
   them, so an operator glued to a word still ends the command
   (`LD_PRELOAD=... :; make` is a `:` and then a `make` the assignment
   persists into).
2. No .ncl file outside packages/detbuild may name libdetbuild, under
   packages/ or stacks/. An `env` or `vars` entry would preload it into the
   whole build, and a stack would preload it into a user's session.
3. A package that preloads libdetbuild must list `detbuild` in its
   build_deps. A build sandbox mounts only the dependency closure, and
   without the library ld.so ignores the preload and the command runs
   unpinned.
4. A preloaded `cargo` must carry `--frozen` or `--offline` among its own
   words (not after a `#` or a `;`). In a package whose build has the
   network, the preloaded command must be such a cargo command; nothing else
   is allowed. The builder gives a build the network when the package OR
   ANY package in its build closure declares `needs.internet` (minimal
   `crates/op/src/specs.rs`, `rootfs_mapped`): the closure is its
   build_deps and runtime_deps plus the runtime_deps of those, transitively
   (`Transitives::new(.., include_build_deps = true)`). So a package that
   build-depends on `rust` (which declares it) has the network without
   saying so. The closure is read from `mip dump` of the catalog, every
   arch given; a preloading package the dump does not resolve is rejected.
   Fetch first without the preload. `--frozen` is a necessary condition,
   not a proof the step is offline: it stops cargo fetching crates, but a
   `build.rs` can still download (rusty_v8, ort-sys and similar do), and
   would do that TLS under the preload, so pre-fetch those too (AGENTS.md).

This checks sources only. Rejecting libdetbuild strings that a build captures
into its outputs (libtool wrappers, configure caches) needs the built tree,
which is minimal's checker suite (gominimal/minimal#2489).

Usage: detbuild_preload_guard.py --dump DUMP.json [--dump ...] [REPO_ROOT],
where each DUMP is `mip dump -p --format json --arch <arch>` of REPO_ROOT.
Exits 1 on any violation, and prints how many preloads it checked, so an
empty pass is visible.
"""

import argparse
import json
import pathlib
import re
import shlex
import sys

LIB = "libdetbuild"
# Where a simple command starts: the line start, or after an operator that
# ends the previous one (`;` `&` `&&` `|` `||`), a subshell/group/negation/
# command-substitution opener, then optionally a reserved word that itself
# sits at a command start (`if`, `then`, `do`, ...). Only there is
# `LD_PRELOAD=<path>` a prefix scoped to the command after it. Anywhere else
# it is an argument to some other word: `export`/`local -x`/`declare -g -x`/
# `command export`/`builtin export` (which set it for every later command),
# or `make LD_PRELOAD=...` (make exports command-line variables into every
# recipe).
COMMAND_START = r"(?:^|[;&|({!`])\s*(?:(?:if|then|else|elif|do|while|until|time)\s+)*"
PREFIX = re.compile(
    COMMAND_START + r"(?:env\s+)?LD_PRELOAD=(?P<q>[\"']?)\S*libdetbuild\.so(?P=q)\s+(?P<cmd>\S.*)$"
)
# A declaration builtin with LD_PRELOAD among its arguments, wherever it sits
# on the line and whatever its flags (`cd x && export ...`, `declare -g -x`,
# `local -x`, `command export`). Rejected with the clearer message; PREFIX
# would reject these too, since none puts LD_PRELOAD= at a command start.
EXPORTED = re.compile(r"(?:^|[\s;&|({`])(?:export|local|readonly|declare|typeset)\b[^;&|]*\bLD_PRELOAD")
# A leading `NAME=value` word: another assignment, not a command.
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\+?=")
# POSIX special builtins: an assignment before one outlives it under sh.
# Reserved words and a word built by expansion are rejected with them: the
# first is not a command after an assignment, the second may expand to one.
SPECIAL_BUILTINS = {
    ":", ".", "source", "break", "continue", "eval", "exec", "exit", "export",
    "readonly", "return", "set", "shift", "times", "trap", "unset",
}
NOT_A_COMMAND_WORD = SPECIAL_BUILTINS | {"{", "}", "!", "[[", "]]", "`"}
# Redirection operators as shlex groups them. Every other punctuation token
# (`;` `&` `&&` `|` `||` `|&` `(` `)` `;;` ...) ends the simple command.
REDIRECTIONS = {"<", ">", ">>", "<<", "<<<", "<>", ">|", "<&", ">&", "&>", "&>>"}
# An fd number glued to a redirection (`2>log`, `2>&1`): drop the number so
# it is not read as a word. Only at a word start, so `-j4>log` keeps `-j4`.
FD_REDIRECT = re.compile(r"(?<![^\s;&|()])[0-9]+(?=[<>])")
# `unset LD_PRELOAD` alone on its line (a trailing comment is fine). Nothing
# may follow it: `unset LD_PRELOAD; LD_PRELOAD=$P; export LD_PRELOAD` would
# otherwise be skipped as an unset and re-export the preload.
UNSET = re.compile(r"^\s*unset\s+(?:-v\s+)?LD_PRELOAD\s*(?:#.*)?$")
INTERNET = re.compile(r"\binternet\s*=\s*\{")
OFFLINE_FLAGS = {"--frozen", "--offline"}


def preloaded_command(rest):
    """The words of the simple command that `LD_PRELOAD=<path>` prefixes,
    given the text after the path, or None if it prefixes no command.

    The text is split the way the shell splits it (shlex with
    punctuation_chars), so an operator glued to a word is still an operator:
    `:; make` is `:` `;` `make`. Leading assignments and redirections are
    skipped; the first other word is the command word, and the command ends
    at the first control operator. A `#` starts a comment even inside a word
    (`build#x`), which is stricter than the shell, never looser. A `$(...)`
    stays inside its word. Unbalanced quotes give None."""
    lexer = shlex.shlex(FD_REDIRECT.sub("", rest), posix=True, punctuation_chars=True)
    try:
        tokens = list(lexer)
    except ValueError:
        return None
    punct = set(lexer.punctuation_chars)
    words, i = [], 0
    while i < len(tokens):
        tok = tokens[i]
        if tok == "$" and i + 1 < len(tokens) and tokens[i + 1] == "(":
            # Command substitution: one word, up to the matching `)`.
            depth, j = 0, i + 1
            while j < len(tokens):
                depth += tokens[j].count("(") - tokens[j].count(")")
                j += 1
                if depth <= 0:
                    break
            words.append("$(" + " ".join(tokens[i + 2 : j - 1]) + ")")
            i = j
            continue
        if tok and set(tok) <= punct:
            if tok in REDIRECTIONS:
                i += 2  # the operator and its target
                continue
            break  # a control operator: the preloaded command ends here
        if not words and ASSIGNMENT.match(tok):
            i += 1
            continue
        words.append(tok)
        i += 1
    if not words or words[0] in NOT_A_COMMAND_WORD or words[0].startswith(("$", "`")):
        return None
    return words


def is_offline_cargo(words):
    return words[0] == "cargo" and any(w in OFFLINE_FLAGS for w in words[1:])


class Catalog:
    """The package graph from one or more `mip dump -p --format json` files
    (one per arch), enough to answer what the builder answers: does a build
    get the network, and is detbuild in its build_deps."""

    def __init__(self, dumps):
        # One {name: package} map per arch.
        self.arches = [{p["name"]: p for p in dump} for dump in dumps]

    @staticmethod
    def _names(refs):
        for r in refs:
            if r.get("type") == "package":
                yield r["name"]
            elif r.get("type") == "subset_of":
                yield r["package"]

    def _networked_on(self, pkgs, name):
        """True, False, or None when a package in the closure is missing."""
        top = pkgs.get(name)
        if top is None:
            return None
        if "internet" in top.get("needs", {}):
            return True
        # The sandbox closure: direct build and runtime deps, then the
        # runtime deps of each, transitively.
        todo = list(self._names(top.get("build_deps", []))) + list(self._names(top.get("runtime_deps", [])))
        seen = set()
        while todo:
            n = todo.pop()
            if n in seen:
                continue
            seen.add(n)
            p = pkgs.get(n)
            if p is None:
                return None
            if "internet" in p.get("needs", {}):
                return True
            todo.extend(self._names(p.get("runtime_deps", [])))
        return False

    def networked(self, name):
        """True if the build has the network on any arch it exists on; None
        if no arch has the package or one cannot resolve its closure."""
        results = [self._networked_on(pkgs, name) for pkgs in self.arches if name in pkgs]
        if not results or None in results:
            return None
        return any(results)

    def has_detbuild(self, name):
        """True if every arch that has the package lists detbuild in its
        build_deps."""
        present = [pkgs[name] for pkgs in self.arches if name in pkgs]
        return bool(present) and all("detbuild" in set(self._names(p.get("build_deps", []))) for p in present)


def is_text(path):
    """A file the guard reads: no NUL byte in its first 8 KiB."""
    try:
        with open(path, "rb") as fh:
            return b"\0" not in fh.read(8192)
    except OSError:
        return False


def strip_comment(line):
    s = line.strip()
    return "" if s.startswith("#") else line


def logical_lines(text):
    """(first line number, line) with backslash-continued lines joined, the
    way the shell reads them, so a preload continued onto the next line is one
    command rather than a preload followed by a lone backslash."""
    out, buf, start = [], [], None
    for n, raw in enumerate(text.splitlines(), 1):
        if start is None:
            start = n
        if raw.endswith("\\") and strip_comment(raw).strip():
            buf.append(raw[:-1])
            continue
        buf.append(raw)
        out.append((start, " ".join(buf)))
        buf, start = [], None
    if buf:
        out.append((start, " ".join(buf)))
    return out


def check_stacks(root):
    """Rule 2 for stacks/: any text file there naming libdetbuild is an error."""
    errors = []
    stacks = root / "stacks"
    if not stacks.is_dir():
        return errors
    for f in sorted(stacks.rglob("*")):
        if not f.is_file() or not is_text(f):
            continue
        rel = f.relative_to(root)
        for n, raw in enumerate(f.read_text(errors="replace").splitlines(), 1):
            if LIB in strip_comment(raw):
                errors.append(f"{rel}:{n}: libdetbuild named in a stack; it may only be preloaded on one build command")
    return errors


def check(root, catalog):
    pkgs = root / "packages"
    errors = check_stacks(root)
    uses = 0
    for pkg in sorted(p for p in pkgs.iterdir() if p.is_dir()):
        if pkg.name == "detbuild":
            continue
        ncl = pkg / "build.ncl"
        # The package's own declaration, read from source, or any package in
        # its build closure, read from the catalog. None means the catalog
        # could not resolve the closure, which is treated as networked.
        declares = ncl.is_file() and bool(INTERNET.search(ncl.read_text(errors="replace")))
        networked = True if declares else catalog.networked(pkg.name)
        pkg_uses = 0
        for f in sorted(pkg.rglob("*")):
            if not f.is_file() or not is_text(f):
                continue
            rel = f.relative_to(root)
            lines = [(n, strip_comment(raw)) for n, raw in logical_lines(f.read_text(errors="replace"))]
            if f.suffix != ".ncl" and any(LIB in line for _, line in lines):
                # Once a file preloads the library, LD_PRELOAD may appear only
                # in the checked prefix: `export LD_PRELOAD`, `true && export
                # LD_PRELOAD`, `eval ...` would each carry an assignment to
                # every later command.
                for n, line in lines:
                    if LIB in line or "LD_PRELOAD" not in line or UNSET.match(line):
                        continue
                    kind = "exported" if EXPORTED.search(line) or "export" in line else "used outside the one prefix"
                    errors.append(f"{rel}:{n}: LD_PRELOAD is {kind} in a file that preloads libdetbuild")
            for n, line in lines:
                if LIB not in line:
                    continue
                where = f"{rel}:{n}"
                if f.suffix == ".ncl":
                    errors.append(f"{where}: libdetbuild named in a .ncl file; preload it on one command in build.sh instead")
                    continue
                if EXPORTED.search(line):
                    errors.append(f"{where}: LD_PRELOAD of libdetbuild is exported; use `LD_PRELOAD=... <command>` on the one command")
                    continue
                m = PREFIX.search(line)
                words = preloaded_command(m.group("cmd")) if m else None
                if words is None or line.count("LD_PRELOAD") != 1:
                    errors.append(f"{where}: libdetbuild is not used as a `LD_PRELOAD=... <command>` prefix")
                    continue
                uses += 1
                pkg_uses += 1
                if words[0] == "cargo" and not is_offline_cargo(words):
                    errors.append(
                        f"{where}: a preloaded cargo must run offline (`cargo build --frozen`, after an "
                        f"unpreloaded `cargo fetch --locked`)"
                    )
                elif networked is not False and not is_offline_cargo(words):
                    if declares:
                        why = "declares needs.internet"
                    elif networked is None:
                        why = "has a build closure the catalog dump does not resolve, so it counts as networked"
                    else:
                        why = "has the network through its build closure (a dependency declares needs.internet)"
                    errors.append(
                        f"{where}: {pkg.name} {why}, so the preloaded command must run offline "
                        f"(`cargo build --frozen`, after an unpreloaded `cargo fetch --locked`)"
                    )
        if pkg_uses and not catalog.has_detbuild(pkg.name):
            errors.append(
                f"packages/{pkg.name}: preloads libdetbuild but does not list `detbuild` in build_deps "
                f"on every arch, so the build sandbox has no library and ld.so ignores the preload"
            )
    return uses, errors


def main(argv=None):
    ap = argparse.ArgumentParser(description="Keep libdetbuild preloads scoped to one offline build command.")
    ap.add_argument("root", nargs="?", default=".", help="the pkgs checkout")
    ap.add_argument(
        "--dump",
        action="append",
        required=True,
        metavar="JSON",
        help="`mip dump -p --format json --arch <arch>` of ROOT; give one per arch",
    )
    args = ap.parse_args(argv)
    root = pathlib.Path(args.root).resolve()
    if not (root / "packages" / "detbuild").is_dir():
        print(f"ERROR: {root}/packages/detbuild not found; wrong repo root?", file=sys.stderr)
        return 1
    dumps = []
    for path in args.dump:
        try:
            dump = json.loads(pathlib.Path(path).read_text())
        except (OSError, ValueError) as e:
            print(f"ERROR: cannot read catalog dump {path}: {e}", file=sys.stderr)
            return 1
        if not isinstance(dump, list) or not any(p.get("name") == "detbuild" for p in dump):
            print(f"ERROR: {path} is not a catalog dump of {root} (no detbuild package)", file=sys.stderr)
            return 1
        dumps.append(dump)
    uses, errors = check(root, Catalog(dumps))
    for e in errors:
        print(f"ERROR: {e}", file=sys.stderr)
    print(f"detbuild preload guard: {uses} preload(s) checked, {len(errors)} violation(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
