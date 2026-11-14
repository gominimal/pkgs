#!/usr/bin/env python3
"""gcc-runtime guard: runtime deps take gcc's libraries from gcc-runtime (gominimal/inbox#1261).

A subset dependency does not fetch only its outputs. The client fetches the
parent's WHOLE build artifact and cuts the subset out locally, and the closure
also takes in every runtime_dep of the parent. So `subsetOf gcc ["libgcc"]`
costs a session the whole compiler (~300 MB unpacked) plus gmp, mpc, mpfr,
zlib, zstd, lz4 and xz, to get a 1 MB libgcc_s. packages/gcc-runtime ships
just the shared runtime libraries, with gcc's output names (libgcc, libstdcpp,
libgomp, libatomic, libgfortran, amd64 libquadmath) and runtime_deps [glibc].

This guard reads every .ncl under packages/ and, inside every `runtime_deps`
field (a replace_on_cycle breaker's included), rejects:

  1. subset        `subsetOf gcc ...` in any form (one line, multi-line, with
                   an `@ match` arch list). Use `subsetOf gcc-runtime [...]`
                   with the same output list.
  2. whole-gcc     a bare `gcc` dep: the whole compiler at runtime. Only a
                   package that runs the compiler may do that, and it goes in
                   WHOLE_GCC_ALLOWED with the reason. A package that only needs
                   the libraries takes `subsetOf gcc-runtime [...]`.

build_deps, test_deps and tests are not checked: building or testing with gcc
is what gcc is for. `gcc` here means the identifier bound to
`import ".../gcc/build.ncl"` in the file (whatever it is called), not
gcc-runtime or gcc-arm-none-eabi. Comments and strings are ignored.

An allowlist entry whose package no longer takes whole gcc fails as stale, so
the list cannot outlive its reason.

Usage: gcc_runtime_guard.py [REPO_ROOT]   (default: the current directory)

Exit codes: 0 = PASS, 1 = violations found, 2 = UNVERIFIED (no packages, or
too few runtime_deps fields parsed to trust the scan). 2 is deliberately
non-zero: a guard that cannot see the catalog must not report success.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

# Package directory name -> why it takes the whole compiler at runtime.
WHOLE_GCC_ALLOWED: dict[str, str] = {
    "toolchain": "the C toolchain meta package: gcc is what it ships",
}
# A scan that parsed fewer runtime_deps fields than this saw a broken tree or
# a broken parser, not the catalog (~1000 today).
MIN_RUNTIME_FIELDS = 100

IDENT_CHARS = r"A-Za-z0-9_'\-"
GCC_IMPORT = re.compile(r"""import\s+"(?:[^"]*/)?gcc/build\.ncl\"""")
LET_GCC = re.compile(
    rf"""\blet\s+([A-Za-z_][{IDENT_CHARS}]*)\s*=\s*import\s+"(?:[^"]*/)?gcc/build\.ncl\""""
)
RUNTIME_FIELD = re.compile(rf"(?<![{IDENT_CHARS}.])runtime_deps\s*=")
OPEN = "([{"
CLOSE = ")]}"


def strip(text: str, keep_strings: bool) -> str:
    """Blank out comments (and, unless keep_strings, string bodies), keeping
    every offset and newline, so later regexes see only code."""
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "#":
            j = text.find("\n", i)
            j = n if j == -1 else j
            for k in range(i, j):
                out[k] = " "
            i = j
            continue
        m = re.match(r'm(%+)"', text[i:]) if c == "m" and (i == 0 or not re.match(rf"[{IDENT_CHARS}]", text[i - 1])) else None
        if m:
            close = '"' + m.group(1)
            j = text.find(close, i + len(m.group(0)))
            j = n if j == -1 else j + len(close)
            if not keep_strings:
                for k in range(i, j):
                    if out[k] != "\n":
                        out[k] = " "
            i = j
            continue
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            j = min(j + 1, n)
            if not keep_strings:
                for k in range(i + 1, j - 1):
                    if out[k] != "\n":
                        out[k] = " "
            i = j
            continue
        i += 1
    return "".join(out)


def field_end(code: str, start: int) -> int:
    """Offset where the field value starting at `start` ends: the first `,` at
    depth 0, or the bracket that closes the enclosing record."""
    depth = 0
    for i in range(start, len(code)):
        c = code[i]
        if c in OPEN:
            depth += 1
        elif c in CLOSE:
            if depth == 0:
                return i
            depth -= 1
        elif c == "," and depth == 0:
            return i
    return len(code)


def gcc_names(code_with_strings: str) -> set[str]:
    return set(LET_GCC.findall(code_with_strings))


def scan_text(text: str) -> tuple[int, list[tuple[int, str, str]]]:
    """(runtime_deps fields seen, [(line, rule, detail)])."""
    with_strings = strip(text, keep_strings=True)
    code = strip(text, keep_strings=False)
    names = gcc_names(with_strings)
    findings = []
    fields = 0
    for m in RUNTIME_FIELD.finditer(code):
        fields += 1
        lo, hi = m.end(), field_end(code, m.end())
        value, value_s = code[lo:hi], with_strings[lo:hi]

        def line_of(off: int) -> int:
            return text.count("\n", 0, lo + off) + 1

        for imp in GCC_IMPORT.finditer(value_s):
            findings.append((line_of(imp.start()), "inline-import", "runtime_deps imports gcc/build.ncl inline"))
        for name in sorted(names):
            tok = re.compile(rf"(?<![{IDENT_CHARS}.])(subsetOf\s+)?{re.escape(name)}(?![{IDENT_CHARS}.])")
            for t in tok.finditer(value):
                if t.group(1):
                    findings.append((line_of(t.start()), "subset", f"`subsetOf {name}` (gcc)"))
                else:
                    findings.append((line_of(t.start()), "whole-gcc", f"whole `{name}` (gcc)"))
    return fields, findings


def package_of(rel: str) -> str:
    parts = rel.split(os.sep)
    return parts[1] if len(parts) > 2 and parts[0] == "packages" else rel


def scan_repo(root: str) -> tuple[int, int, dict[str, list[str]]]:
    """(files, runtime_deps fields, {package: [problem]})."""
    problems: dict[str, list[str]] = {}
    whole: set[str] = set()
    files = fields = 0
    pkgs_dir = os.path.join(root, "packages")
    for dirpath, dirnames, filenames in os.walk(pkgs_dir):
        dirnames.sort()
        for fn in sorted(filenames):
            if not fn.endswith(".ncl"):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, root)
            pkg = package_of(rel)
            if pkg == "gcc":
                continue  # gcc's own breaker and helpers are gcc itself
            with open(path, encoding="utf-8") as f:
                text = f.read()
            files += 1
            n, found = scan_text(text)
            fields += n
            for line, rule, detail in found:
                if rule == "whole-gcc" and pkg in WHOLE_GCC_ALLOWED:
                    whole.add(pkg)
                    continue
                if rule == "subset":
                    fix = "use `subsetOf gcc-runtime [...]` with the same outputs"
                elif rule == "whole-gcc":
                    fix = (
                        "take `subsetOf gcc-runtime [...]` for the libraries, or add the package to "
                        "WHOLE_GCC_ALLOWED with the reason it runs the compiler"
                    )
                else:
                    fix = "bind it with `let gcc-runtime = import ...` and take `subsetOf gcc-runtime [...]`"
                problems.setdefault(pkg, []).append(f"{rel}:{line}: {rule}: {detail} in runtime_deps; {fix}")
    for pkg, why in sorted(WHOLE_GCC_ALLOWED.items()):
        if pkg not in whole:
            problems.setdefault(pkg, []).append(
                f"stale-allowlist: WHOLE_GCC_ALLOWED[{pkg!r}] ({why}) but no runtime_deps takes whole gcc; remove the entry"
            )
    return files, fields, problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("root", nargs="?", default=".", help="pkgs checkout (default: .)")
    ap.add_argument("--min-fields", type=int, default=MIN_RUNTIME_FIELDS, help=argparse.SUPPRESS)
    args = ap.parse_args(argv)

    if not os.path.isdir(os.path.join(args.root, "packages")):
        print(f"UNVERIFIED: no packages/ under {args.root}", file=sys.stderr)
        return 2
    files, fields, problems = scan_repo(args.root)
    if fields < args.min_fields:
        print(f"UNVERIFIED: parsed only {fields} runtime_deps fields in {files} files", file=sys.stderr)
        return 2

    lines = []
    if problems:
        lines.append(f"## gcc-runtime guard: {len(problems)} package(s) FAIL ({files} files, {fields} runtime_deps)\n")
        lines.append("A gcc subset fetches the whole compiler and its runtime_deps; take gcc-runtime (inbox#1261).\n")
        for pkg in sorted(problems):
            for p in problems[pkg]:
                lines.append(f"- `{pkg}`: {p}")
                print(f"::error title=gcc-runtime guard ({pkg})::{p}")
    else:
        lines.append(f"## gcc-runtime guard: PASS ({files} files, {fields} runtime_deps)\n")
    text = "\n".join(lines) + "\n"
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(text)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
