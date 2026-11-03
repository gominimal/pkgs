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
   `unset LD_PRELOAD`), so a later `export LD_PRELOAD`, wherever it sits on
   its line (`true && export LD_PRELOAD`), is rejected too. The prefix
   itself must sit where a command starts (line start, after `;` `&&` `||`
   `|` `(` `{` `!`, or `if`/`then`/`do`/...): `cd x && export
   LD_PRELOAD=<path> make`, `local -x LD_PRELOAD=<path> cargo` and `make
   LD_PRELOAD=<path> cc` name the path but are not prefixes.
   Backslash-continued lines are joined first, so a preloaded command may span
   lines.
2. No .ncl file outside packages/detbuild may name libdetbuild, under
   packages/ or stacks/. An `env` or `vars` entry would preload it into the
   whole build, and a stack would preload it into a user's session.
3. If the package declares `needs.internet`, the preloaded command must be
   `cargo ... --frozen` or `cargo ... --offline`. Fetch first without the
   preload. This is a necessary condition, not a proof the step is offline:
   `--frozen` stops cargo fetching crates, but a `build.rs` can still download
   (rusty_v8, ort-sys and similar do), and would do that TLS under the
   preload, so pre-fetch those too (AGENTS.md). Any other preloaded command in
   a networked package is rejected, since nothing else is even that much.

This checks sources only. Rejecting libdetbuild strings that a build captures
into its outputs (libtool wrappers, configure caches) needs the built tree,
which is minimal's checker suite (gominimal/minimal#2489).

Usage: detbuild_preload_guard.py [REPO_ROOT]. Exits 1 on any violation, and
prints how many preloads it checked, so an empty pass is visible.
"""

import pathlib
import re
import sys

LIB = "libdetbuild"
# Where a simple command starts: the line start, or after an operator that
# ends the previous one (`;` `&` `&&` `|` `||`), a subshell/group/negation/
# command-substitution opener, then optionally a reserved word that itself
# sits at a command start (`if`, `then`, `do`, ...). Only there is
# `LD_PRELOAD=<path>` a prefix scoped to the command after it. Anywhere else
# it is an argument to some other word: `export`/`local -x`/`declare -g -x`/
# `command export`/`builtin export` (which set it for every later command,
# pkgs#884 review 2026-11-03), or `make LD_PRELOAD=...` (make exports
# command-line variables into every recipe).
COMMAND_START = r"(?:^|[;&|({!`])\s*(?:(?:if|then|else|elif|do|while|until|time)\s+)*"
PREFIX = re.compile(
    COMMAND_START + r"(?:env\s+)?LD_PRELOAD=(?P<q>[\"']?)\S*libdetbuild\.so(?P=q)\s+(?P<cmd>\S.*)$"
)
# A declaration builtin with LD_PRELOAD among its arguments, wherever it sits
# on the line and whatever its flags (`cd x && export ...`, `declare -g -x`,
# `local -x`, `command export`). Rejected with the clearer message; PREFIX
# would reject these too, since none puts LD_PRELOAD= at a command start.
EXPORTED = re.compile(r"(?:^|[\s;&|({`])(?:export|local|readonly|declare|typeset)\b[^;&|]*\bLD_PRELOAD")
# What follows `LD_PRELOAD=<path>` when it is not a command: a comment, or a
# shell operator that ends the simple command (the assignment then persists).
NOT_A_COMMAND = re.compile(r"^(?:#|;|&|\||\)|\(|\{|\}|<|>|[0-9]+[<>])")
# Leading `NAME=value` words after the preload: more assignments, not a command.
ASSIGNMENTS = re.compile(r"""^(?:[A-Za-z_][A-Za-z0-9_]*\+?=(?:"[^"]*"|'[^']*'|[^\s"'])*\s*)*""")
# POSIX special builtins: an assignment before one outlives it under sh.
SPECIAL_BUILTINS = {
    ":", ".", "source", "break", "continue", "eval", "exec", "exit", "export",
    "readonly", "return", "set", "shift", "times", "trap", "unset",
}
UNSET = re.compile(r"^\s*unset\s+(?:-v\s+)?LD_PRELOAD\s*(?:[;&|#].*)?$")
INTERNET = re.compile(r"\binternet\s*=\s*\{")
CARGO_OFFLINE = re.compile(r"^cargo\s.*(?:--frozen|--offline)\b")


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


def check(root):
    pkgs = root / "packages"
    errors = check_stacks(root)
    uses = 0
    for pkg in sorted(p for p in pkgs.iterdir() if p.is_dir()):
        if pkg.name == "detbuild":
            continue
        ncl = pkg / "build.ncl"
        networked = ncl.is_file() and bool(INTERNET.search(ncl.read_text(errors="replace")))
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
                cmd = ASSIGNMENTS.sub("", m.group("cmd")) if m else ""
                word = cmd.split(None, 1)[0] if cmd else ""
                if not m or not cmd or NOT_A_COMMAND.match(cmd) or word in SPECIAL_BUILTINS or line.count("LD_PRELOAD") != 1:
                    errors.append(f"{where}: libdetbuild is not used as a `LD_PRELOAD=... <command>` prefix")
                    continue
                uses += 1
                if networked and not CARGO_OFFLINE.match(cmd):
                    errors.append(
                        f"{where}: {pkg.name} declares needs.internet, so the preloaded command must run offline "
                        f"(`cargo build --frozen`, after an unpreloaded `cargo fetch --locked`)"
                    )
    return uses, errors


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    if not (root / "packages" / "detbuild").is_dir():
        print(f"ERROR: {root}/packages/detbuild not found; wrong repo root?", file=sys.stderr)
        return 1
    uses, errors = check(root)
    for e in errors:
        print(f"ERROR: {e}", file=sys.stderr)
    print(f"detbuild preload guard: {uses} preload(s) checked, {len(errors)} violation(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
