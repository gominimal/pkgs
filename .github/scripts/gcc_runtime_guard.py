#!/usr/bin/env python3
"""gcc-runtime guard: runtime deps take gcc's libraries from gcc-runtime (gominimal/inbox#1261).

A subset dependency does not fetch only its outputs. The client fetches the
parent's WHOLE build artifact and cuts the subset out locally, and the closure
also takes in every runtime_dep of the parent. So `subsetOf gcc ["libgcc"]`
costs a session the whole compiler (~300 MB unpacked) plus gmp, mpc, mpfr,
zlib, zstd, lz4 and xz, to get a 1 MB libgcc_s. packages/gcc-runtime ships
just the shared runtime libraries, with gcc's output names (libgcc, libstdcpp,
libgomp, libatomic, libssp, amd64 libquadmath) and runtime_deps [glibc];
libgfortran is in packages/gcc-runtime-fortran.

This guard reads every .ncl under packages/ and, inside every `runtime_deps`
field (a replace_on_cycle breaker's included), rejects:

  1. subset        `subsetOf gcc ...` in any form (one line, multi-line, with
                   an `@ match` arch list). Use `subsetOf gcc-runtime [...]`
                   with the same output list.
  2. whole-gcc     a bare `gcc` dep: the whole compiler at runtime. Only a
                   package that runs the compiler may do that, and it goes in
                   WHOLE_GCC_ALLOWED with the reason. A package that only needs
                   the libraries takes `subsetOf gcc-runtime [...]`.
  3. whole-gcc-runtime
                   a bare `gcc-runtime` dep. Always take a subset: on a
                   bootstrap-cycle edge gcc-runtime is its prebuilt breaker,
                   whose cache entry is the WHOLE extracted prebuilt gcc tree
                   (output globs are not applied to prebuilts; minimal
                   crates/op/src/specs.rs materialize_prebuilt), so a whole
                   dep would link all of that prebuilt gcc into that root.

It also rejects:

  4. gcc-closure   gcc's build graph reaching gcc-runtime or
                   gcc-runtime-fortran. Both copy their files from their gcc
                   build dep. If gcc's graph contains them, cycle breaking
                   resolves gcc differently inside their build (a different
                   replace_on_cycle on the path) than on its own, so they copy
                   a second gcc build whose bytes differ from the published
                   gcc's at the same /usr/lib paths: a file conflict (arch
                   registry spec, registry-model.md §12) in any box that holds
                   both, and gcc built twice. The 16.2 canary had exactly this
                   via binutils, gmp and ncurses. The check follows every
                   dependency outside tests and replace_on_cycle.

build_deps, test_deps and tests are not checked by rules 1-3: building or
testing with gcc is what gcc is for. `gcc` here means the identifier bound to
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
LET_GCC_RUNTIME = re.compile(
    rf"""\blet\s+([A-Za-z_][{IDENT_CHARS}]*)\s*=\s*import\s+"(?:[^"]*/)?gcc-runtime/build\.ncl\""""
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
        for name in sorted(set(LET_GCC_RUNTIME.findall(with_strings))):
            tok = re.compile(rf"(?<![{IDENT_CHARS}.])(subsetOf\s+)?{re.escape(name)}(?![{IDENT_CHARS}.])")
            for t in tok.finditer(value):
                if not t.group(1):
                    findings.append(
                        (line_of(t.start()), "whole-gcc-runtime", f"whole `{name}` (gcc-runtime)")
                    )
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
                elif rule == "whole-gcc-runtime":
                    fix = (
                        "take `subsetOf gcc-runtime [...]`: on a cycle edge the breaker's cache "
                        "entry is the whole prebuilt gcc tree"
                    )
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
    for p in breaker_pin_problems(root):
        problems.setdefault("gcc-runtime", []).append(p)
    for p in stage_helper_problems(root):
        problems.setdefault("gcc-runtime", []).append(p)
    for p in gcc_closure_problems(root):
        problems.setdefault("gcc", []).append(p)
    return files, fields, problems


# Packages that copy their files out of their gcc build dep.
COPIERS = ("gcc-runtime", "gcc-runtime-fortran")
# `let NAME = import "PATH"` and `let NAME = (import "PATH") args`, for a .ncl
# of any name: a package's recipe (`../X/build.ncl`) or a helper in another
# package's directory (`../llvm/versioned.ncl`, `../jdk/cve-2026-111943.ncl`).
LET_ANY_IMPORT = re.compile(
    rf"""\blet\s+([A-Za-z_][{IDENT_CHARS}]*)\s*=\s*\(?\s*import\s+"([^"]+\.ncl)\""""
)
INLINE_ANY_IMPORT = re.compile(r"""\bimport\s+"([^"]+\.ncl)\"""")
NOT_A_DEP = re.compile(rf"(?<![{IDENT_CHARS}.])(?:replace_on_cycle|tests)\s*=")


def blank(text: str, spans: list[tuple[int, int]]) -> str:
    out = list(text)
    for lo, hi in spans:
        for k in range(lo, hi):
            if out[k] != "\n":
                out[k] = " "
    return "".join(out)


def import_target(pkgs_dir: str, path: str, rel: str) -> tuple[str | None, str]:
    """Resolve an import in `path`: (package, file) for `../P/build.ncl`, else
    (None, file) for a helper .ncl."""
    target = os.path.normpath(os.path.join(os.path.dirname(path), rel))
    parts = os.path.relpath(target, pkgs_dir).split(os.sep)
    if len(parts) == 2 and parts[1] == "build.ncl" and not parts[0].startswith(".."):
        return parts[0], target
    return None, target


def file_deps(pkgs_dir: str, path: str, cache: dict[str, set[str]], _seen: frozenset[str] = frozenset()) -> set[str]:
    """Packages that the .ncl at `path` depends on, outside tests and
    replace_on_cycle (a breaker is what a cycle resolves to, not an edge). An
    imported helper .ncl contributes the packages IT depends on, followed
    across directories (llvm-22 -> llvm/versioned.ncl)."""
    path = os.path.normpath(path)
    if path in cache:
        return cache[path]
    if path in _seen or not os.path.isfile(path):
        return set()
    with open(path, encoding="utf-8") as f:
        text = f.read()
    with_strings = strip(text, keep_strings=True)
    code = strip(text, keep_strings=False)
    lets = list(LET_ANY_IMPORT.finditer(with_strings))
    spans = [(m.start(), m.end()) for m in lets]
    spans += [(m.end(), field_end(code, m.end())) for m in NOT_A_DEP.finditer(code)]
    code, with_strings = blank(code, spans), blank(with_strings, spans)
    deps: set[str] = set()

    def add(rel: str) -> None:
        pkg, target = import_target(pkgs_dir, path, rel)
        if pkg is not None:
            deps.add(pkg)
        else:
            deps.update(file_deps(pkgs_dir, target, cache, _seen | {path}))

    for m in lets:
        name = re.escape(m.group(1))
        # `pkg.version` reads a value off a recipe, not a dep; a helper's use
        # is normally a field read (`llvm.runtime_deps`), so it counts.
        after = IDENT_CHARS if import_target(pkgs_dir, path, m.group(2))[0] is None else IDENT_CHARS + "."
        if re.search(rf"(?<![{IDENT_CHARS}.]){name}(?![{after}])", code):
            add(m.group(2))
    for rel in INLINE_ANY_IMPORT.findall(with_strings):
        add(rel)
    cache[path] = deps
    return deps


def package_deps(root: str) -> dict[str, set[str]]:
    """{package: packages its .ncl files depend on}, helper imports followed."""
    edges: dict[str, set[str]] = {}
    pkgs_dir = os.path.normpath(os.path.join(root, "packages"))
    cache: dict[str, set[str]] = {}
    for pkg in sorted(os.listdir(pkgs_dir)):
        pdir = os.path.join(pkgs_dir, pkg)
        if not os.path.isdir(pdir):
            continue
        deps: set[str] = set()
        for fn in sorted(os.listdir(pdir)):
            if fn.endswith(".ncl"):
                deps |= file_deps(pkgs_dir, os.path.join(pdir, fn), cache)
        deps.discard(pkg)
        edges[pkg] = deps
    return edges


def gcc_closure_problems(root: str) -> list[str]:
    """Rule 4: gcc's build graph must not reach a package that copies from gcc."""
    pkgs_dir = os.path.join(root, "packages")
    present = [c for c in COPIERS if os.path.isdir(os.path.join(pkgs_dir, c))]
    if not present or not os.path.isdir(os.path.join(pkgs_dir, "gcc")):
        return []
    edges = package_deps(root)
    parent: dict[str, str] = {}
    stack = ["gcc"]
    while stack:
        p = stack.pop()
        for d in sorted(edges.get(p, ())):
            if d not in parent and d != "gcc":
                parent[d] = p
                stack.append(d)
    problems = []
    for c in present:
        if c not in parent:
            continue
        path = [c]
        while path[-1] != "gcc":
            path.append(parent[path[-1]])
        problems.append(
            f"gcc-closure: gcc's build graph reaches {c} ({' -> '.join(reversed(path))}), so {c} "
            f"copies a second gcc build whose files differ from gcc's at the same paths; "
            f"drop that dependency from {path[1]}, or move the part that needs it into its own package"
        )
    return problems


STAGE_HELPERS = ("packages/gcc-runtime/stage.sh", "packages/gcc-runtime-fortran/stage.sh")


def stage_helper_problems(root: str) -> list[str]:
    """gcc-runtime and gcc-runtime-fortran each source their own stage.sh (a Local
    file cannot come from another package's directory). The two choose where
    gcc's runtime libraries are copied from and reject mixed gccs, so a fix to
    one must reach the other: they must be byte-identical."""
    paths = [os.path.join(root, p) for p in STAGE_HELPERS]
    if not os.path.exists(os.path.join(root, "packages", "gcc-runtime")):
        return []
    missing = [p for p, full in zip(STAGE_HELPERS, paths) if not os.path.exists(full)]
    if missing:
        return [f"stage-helper: missing {', '.join(missing)}"]
    a, b = (open(p, "rb").read() for p in paths)
    if a != b:
        return [f"stage-helper: {STAGE_HELPERS[0]} and {STAGE_HELPERS[1]} differ; keep them byte-identical"]
    return []


# A gominimal/bootstrap object pin: `url = "gs://minimal-bootstrap/..."` then its sha256.
BREAKER_PIN = re.compile(r'url\s*=\s*"(gs://minimal-bootstrap/[^"]+)"\s*,\s*sha256\s*=\s*"([0-9a-f]{64})"')


def breaker_pins(path: str) -> set[tuple[str, str]]:
    """The (url, sha256) bootstrap pins inside a recipe's replace_on_cycle."""
    with open(path, encoding="utf-8") as f:
        text = strip(f.read(), keep_strings=True)
    at = text.find("replace_on_cycle")
    return set(BREAKER_PIN.findall(text[at:])) if at >= 0 else set()


def breaker_pin_problems(root: str) -> list[str]:
    """gcc-runtime's cycle breaker repacks gcc's prebuilt object, so both must pin
    the same objects. Two copies of a pin drift on the next bootstrap repin: a
    gcc-runtime breaker still on an older gcc's libstdc++ would sit in build
    roots beside the real gcc's (inbox#1261 review)."""
    rt = os.path.join(root, "packages", "gcc-runtime", "build.ncl")
    if not os.path.exists(rt):
        return []
    gcc = os.path.join(root, "packages", "gcc", "build.ncl")
    rt_pins = breaker_pins(rt)
    gcc_pins = breaker_pins(gcc) if os.path.exists(gcc) else set()
    if not rt_pins or not gcc_pins:
        return [
            f"breaker-pins: could not read the bootstrap pins in replace_on_cycle "
            f"(gcc-runtime: {len(rt_pins)}, gcc: {len(gcc_pins)}); both must name the same objects"
        ]
    if rt_pins != gcc_pins:
        only_rt = sorted(u for u, _ in rt_pins - gcc_pins)
        only_gcc = sorted(u for u, _ in gcc_pins - rt_pins)
        return [
            "breaker-pins: gcc-runtime's replace_on_cycle must pin exactly gcc's bootstrap objects; "
            f"only in gcc-runtime: {only_rt}; only in gcc: {only_gcc}. Repin both together."
        ]
    return []


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
