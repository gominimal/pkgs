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
   `env LD_PRELOAD=<path> <command>`). `export LD_PRELOAD=...`, `declare -x`
   and a bare `LD_PRELOAD=...` assignment are rejected: they reach every later
   command, including the ones that fetch.
2. No .ncl file outside packages/detbuild may name libdetbuild, under
   packages/ or stacks/. An `env` or `vars` entry would preload it into the
   whole build, and a stack would preload it into a user's session.
3. If the package declares `needs.internet`, the preloaded command must be
   `cargo ... --frozen` or `cargo ... --offline`. Fetch first without the
   preload. No other command can be shown offline from its text, so any other
   preloaded command in a networked package is rejected.

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
PREFIX = re.compile(
    r"(?:^|[\s;&|(])(?:env\s+)?LD_PRELOAD=(?P<q>[\"']?)\S*libdetbuild\.so(?P=q)\s+(?P<cmd>\S.*)$"
)
EXPORTED = re.compile(r"^\s*(?:export|declare\s+-\w*x\w*|typeset\s+-\w*x\w*)\b.*LD_PRELOAD")
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
            for n, raw in enumerate(f.read_text(errors="replace").splitlines(), 1):
                line = strip_comment(raw)
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
                if not m:
                    errors.append(f"{where}: libdetbuild is not used as a `LD_PRELOAD=... <command>` prefix")
                    continue
                uses += 1
                if networked and not CARGO_OFFLINE.match(m.group("cmd")):
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
