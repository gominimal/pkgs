#!/usr/bin/env python3
"""libgcc dlopen guard: listed importers must have libgcc_s at runtime (pkgs#1545 review).

glibc dlopens libgcc_s.so.1 to unwind on pthread_cancel, pthread_exit and
thrd_exit, and aborts the process when it is missing. backtrace() dlopens it
too and returns no frames without it. A dlopen is not DT_NEEDED, so minimal's
missing-runtime_deps check cannot see it, and a package that gets libgcc_s
only through some other dependency's runtime_deps loses it when that
dependency drops it.

libgcc_dlopen_importers.toml (next to this script) lists every package whose
shipped ELFs import one of those symbols; libgcc_dlopen_scan.py keeps it true
against the built artifacts, weekly. This guard reads only the recipes, so it
runs on every PR: for each listed package it computes the RUNTIME closure
from the .ncl files and requires gcc-runtime's libgcc somewhere in it.

  runtime closure  the package's `runtime_deps`, transitively. build_deps,
                   test_deps, tests and replace_on_cycle are not followed
                   (none of them is in a session). A `subsetOf P [...]` edge
                   also takes in P's own runtime_deps, as the client does.
                   A `runtime_deps = helper.runtime_deps` that delegates to an
                   imported helper .ncl (llvm-22 -> llvm/versioned.ncl) is
                   followed into the helper.
  provides libgcc  `subsetOf gcc-runtime [...]` whose output list names
                   "libgcc" (also inside `["libgcc"] @ match {...}`), or a whole
                   `gcc-runtime` or `gcc` dep (gcc_runtime_guard.py rejects
                   those except toolchain's whole gcc, which ships libgcc_s),
                   or being gcc / gcc-runtime itself.

The fix for a failure is `subsetOf gcc-runtime ["libgcc"]` in the package's
runtime_deps (or in a runtime dep's, when the dep really loads it too).

The guard has no arch. A dep chosen by an `if`/`match` (openjdk's
`if is_arm then [glibc, toolchain] else [glibc]`) may be absent on one arch,
so it is neither followed nor trusted to bring libgcc: the guard fails closed
there, and the fix is the same unconditional subset. A dep reached through a
non-import let binding (`let deps = [...] in`) is not followed either. On the
gcc 16 tree the parsed edges match `mip dump --packages` for both arches, and
the guard's verdict matches the dump's on every package.

Parsing helpers (strip, field_end, blank, the runtime_deps and
replace_on_cycle/tests patterns) come from gcc_runtime_guard.py.

Usage: libgcc_dlopen_guard.py [REPO_ROOT]   (default: the current directory)

Exit codes: 0 = PASS, 1 = violations, 2 = UNVERIFIED (no packages, an
unreadable or near-empty data file, or too few runtime_deps parsed to trust
the scan).
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tomllib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gcc_runtime_guard import (  # noqa: E402
    CLOSE,
    IDENT_CHARS,
    LET_ANY_IMPORT,
    NOT_A_DEP,
    OPEN,
    RUNTIME_FIELD,
    blank,
    field_end,
    strip,
)

SYMBOLS = ("backtrace", "pthread_cancel", "pthread_exit", "thrd_exit")
PROVIDERS = ("gcc-runtime", "gcc")  # packages whose `libgcc` output is libgcc_s
DEFAULT_DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "libgcc_dlopen_importers.toml")
# Fewer than this many parsed runtime_deps fields = a broken tree or parser.
MIN_RUNTIME_FIELDS = 100
# A data file with fewer entries than this was truncated (80 today).
MIN_IMPORTERS = 10
FIX = 'add `subsetOf gcc-runtime ["libgcc"]` to its runtime_deps'

INLINE_PKG_IMPORT = re.compile(r"""\bimport\s+"\.\./([^"/]+)/build\.ncl\"""")
# (dependency package, brings libgcc if it is a provider, chosen by if/match)
Edge = tuple[str, bool, bool]


def _bracket_span(code: str, i: int) -> tuple[int, int] | None:
    """Span of the bracketed expression starting at code[i] (after spaces)."""
    while i < len(code) and code[i].isspace():
        i += 1
    if i >= len(code) or code[i] not in OPEN:
        return None
    depth = 0
    for j in range(i, len(code)):
        if code[j] in OPEN:
            depth += 1
        elif code[j] in CLOSE:
            depth -= 1
            if depth == 0:
                return i, j + 1
    return i, len(code)


COND = re.compile(r"\b(?:then|else)\b|=>")


def _direct_keyword(code: str, lo: int, hi: int) -> bool:
    """True if code[lo:hi] has `then`, `else` or `=>` outside any bracket nested in it."""
    depth = 0
    i = lo
    while i < hi:
        c = code[i]
        if c in OPEN:
            depth += 1
        elif c in CLOSE:
            depth -= 1
        elif depth == 0 and COND.match(code, i):
            return True
        i += 1
    return False


def conditional(code: str, lo: int, hi: int, pos: int) -> bool:
    """Is the dep at `pos` in the value code[lo:hi] chosen by an `if` or `match`
    (an enclosing group, or the value itself, branches at its own level)?
    Such a dep may exist on one arch only, so it is not trusted to bring libgcc."""
    stack: list[int] = []
    for i in range(lo, pos):
        if code[i] in OPEN:
            stack.append(i)
        elif code[i] in CLOSE and stack:
            stack.pop()
    if _direct_keyword(code, lo, hi):
        return True
    for s in stack:
        span = _bracket_span(code, s)
        if span and _direct_keyword(code, span[0] + 1, span[1] - 1):
            return True
    return False


class Recipes:
    """Runtime edges read from packages/*/build.ncl and the helpers they import."""

    def __init__(self, root: str):
        self.root = os.path.abspath(root)
        self.pkgs_dir = os.path.join(self.root, "packages")
        self.fields = 0
        self._file_cache: dict[str, list[Edge]] = {}
        self._pkg_cache: dict[str, list[Edge]] = {}

    def package_of(self, path: str) -> str | None:
        """packages/<P>/build.ncl -> P; anything else (a helper) -> None."""
        rel = os.path.relpath(path, self.pkgs_dir).split(os.sep)
        if len(rel) == 2 and rel[1] == "build.ncl" and not rel[0].startswith(".."):
            return rel[0]
        return None

    def file_edges(self, path: str, _seen: frozenset[str] = frozenset()) -> list[Edge]:
        """[(package, libgcc, conditional)] from every runtime_deps field in
        `path`, outside replace_on_cycle and tests. `libgcc`: the edge brings
        libgcc_s itself if the package is a provider (a whole dep, or a subset
        whose output list names "libgcc"). `conditional`: chosen by an
        if/match, so possibly on one arch only."""
        path = os.path.normpath(path)
        if path in self._file_cache:
            return self._file_cache[path]
        if path in _seen or not os.path.isfile(path):
            return []
        with open(path, encoding="utf-8") as f:
            text = f.read()
        with_strings = strip(text, keep_strings=True)
        code = strip(text, keep_strings=False)
        lets = {}
        for m in LET_ANY_IMPORT.finditer(with_strings):
            lets[m.group(1)] = os.path.normpath(os.path.join(os.path.dirname(path), m.group(2)))
        skip = [(m.end(), field_end(code, m.end())) for m in NOT_A_DEP.finditer(code)]
        code, with_strings = blank(code, skip), blank(with_strings, skip)
        edges: list[Edge] = []
        for m in RUNTIME_FIELD.finditer(code):
            self.fields += 1
            lo, hi = m.end(), field_end(code, m.end())
            for imp in INLINE_PKG_IMPORT.finditer(with_strings, lo, hi):
                edges.append((imp.group(1), True, conditional(code, lo, hi, imp.start())))
            for name, target in sorted(lets.items()):
                tok = re.compile(
                    rf"(?<![{IDENT_CHARS}.])(subsetOf\s+)?{re.escape(name)}(?![{IDENT_CHARS}])(\.runtime_deps)?"
                )
                for t in tok.finditer(code, lo, hi):
                    cond = conditional(code, lo, hi, t.start())
                    pkg = self.package_of(target)
                    if t.group(2) and not t.group(1):
                        # `x.runtime_deps`: x's deps, not x (llvm-22 -> llvm/versioned.ncl).
                        for d, lib, c in self.file_edges(target, _seen | {path}):
                            edges.append((d, lib, c or cond))
                        continue
                    if pkg is None:
                        continue  # any other use of a helper is not a dep
                    if code[t.end() : t.end() + 1] == ".":
                        continue  # `pkg.field`: a value read off the recipe, not a dep
                    if t.group(1):
                        span = _bracket_span(code, t.end())
                        args = with_strings[span[0] : span[1]] if span else ""
                        edges.append((pkg, '"libgcc"' in args, cond))
                    else:
                        edges.append((pkg, True, cond))
        self._file_cache[path] = edges
        return edges

    def edges(self, pkg: str) -> list[Edge]:
        if pkg not in self._pkg_cache:
            self._pkg_cache[pkg] = self.file_edges(os.path.join(self.pkgs_dir, pkg, "build.ncl"))
        return self._pkg_cache[pkg]

    def libgcc_path(self, pkg: str) -> list[str] | None:
        """The runtime path from `pkg` to a libgcc provider, or None. Only
        unconditional edges count: a dep chosen by if/match may be missing on
        one arch, and this guard has no arch, so it fails closed there."""
        if pkg in PROVIDERS:
            return [pkg]
        parent: dict[str, str | None] = {pkg: None}
        queue = [pkg]
        while queue:
            p = queue.pop(0)
            for dep, libgcc, cond in self.edges(p):
                if cond:
                    continue
                if dep in PROVIDERS and libgcc:
                    path = [dep, p]
                    while parent[path[-1]] is not None:
                        path.append(parent[path[-1]])
                    return list(reversed(path))
                if dep not in parent:
                    parent[dep] = p
                    queue.append(dep)
        return None


def load_importers(path: str) -> dict[str, dict]:
    with open(path, "rb") as f:
        doc = tomllib.load(f)
    imp = doc.get("importers")
    if not isinstance(imp, dict):
        raise ValueError("no [importers] table")
    for pkg, e in imp.items():
        syms = e.get("symbols") if isinstance(e, dict) else None
        if not syms or not set(syms) <= set(SYMBOLS):
            raise ValueError(f"importers.{pkg}: symbols must be a non-empty subset of {list(SYMBOLS)}")
    return imp


def load_build_only(path: str) -> dict[str, str]:
    """{package: reason} from libgcc_dlopen_build_only.toml; no file = none."""
    if not os.path.exists(path):
        return {}
    with open(path, "rb") as f:
        doc = tomllib.load(f)
    out = {}
    for pkg, e in (doc.get("build_only") or {}).items():
        reason = e.get("reason") if isinstance(e, dict) else None
        if not reason:
            raise ValueError(f"build_only.{pkg}: needs a reason")
        out[pkg] = reason
    return out


def check(
    root: str, importers: dict[str, dict], build_only: dict[str, str] | None = None
) -> tuple[Recipes, dict[str, str]]:
    """(recipes, {package: problem})."""
    build_only = build_only or {}
    r = Recipes(root)
    # Parse the whole catalog once, so the field count says the parser saw it.
    for pkg in sorted(os.listdir(r.pkgs_dir)):
        if os.path.isfile(os.path.join(r.pkgs_dir, pkg, "build.ncl")):
            r.edges(pkg)
    problems: dict[str, str] = {}
    # A build-only package is exempt because no box runs it: hold it to that.
    for pkg in sorted(build_only):
        if not os.path.isfile(os.path.join(r.pkgs_dir, pkg, "build.ncl")):
            problems[pkg] = (
                f"listed as build-only but packages/{pkg}/build.ncl does not exist; "
                "remove it from libgcc_dlopen_build_only.toml"
            )
            continue
        users = sorted(p for p in r._pkg_cache if any(d == pkg for d, _, _ in r._pkg_cache[p]))
        if users:
            problems[pkg] = (
                f"`{pkg}` is exempt as build-only, but {', '.join(users)} take it in runtime_deps; "
                "give it libgcc or drop the exemption in libgcc_dlopen_build_only.toml"
            )
    for pkg in sorted(importers):
        if pkg in build_only:
            continue
        e = importers[pkg]
        syms = ", ".join(sorted(e["symbols"]))
        ev = (e.get("elfs") or ["?"])[0]
        if not os.path.isfile(os.path.join(r.pkgs_dir, pkg, "build.ncl")):
            problems[pkg] = (
                f"listed as importing {syms} but packages/{pkg}/build.ncl does not exist; "
                "remove it from libgcc_dlopen_importers.toml"
            )
            continue
        if r.libgcc_path(pkg) is None:
            problems[pkg] = (
                f"`{pkg}` imports {syms} ({ev}), for which glibc dlopens libgcc_s.so.1, "
                f"but its runtime closure has no gcc-runtime libgcc; {FIX} in packages/{pkg}/build.ncl"
            )
    return r, problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("root", nargs="?", default=".", help="pkgs checkout (default: .)")
    ap.add_argument("--data", default=None, help="importers TOML (default: the repo's copy)")
    ap.add_argument("--min-fields", type=int, default=MIN_RUNTIME_FIELDS, help=argparse.SUPPRESS)
    ap.add_argument("--min-importers", type=int, default=MIN_IMPORTERS, help=argparse.SUPPRESS)
    args = ap.parse_args(argv)
    data = args.data or os.path.join(args.root, ".github", "scripts", "libgcc_dlopen_importers.toml")

    if not os.path.isdir(os.path.join(args.root, "packages")):
        print(f"UNVERIFIED: no packages/ under {args.root}", file=sys.stderr)
        return 2
    try:
        importers = load_importers(data)
    except Exception as e:  # noqa: BLE001
        print(f"UNVERIFIED: cannot read {data}: {e}", file=sys.stderr)
        return 2
    if len(importers) < args.min_importers:
        print(f"UNVERIFIED: {data} lists only {len(importers)} importers", file=sys.stderr)
        return 2
    bo_path = os.path.join(os.path.dirname(data), "libgcc_dlopen_build_only.toml")
    try:
        build_only = load_build_only(bo_path)
    except Exception as e:  # noqa: BLE001
        print(f"UNVERIFIED: cannot read {bo_path}: {e}", file=sys.stderr)
        return 2
    r, problems = check(args.root, importers, build_only)
    if r.fields < args.min_fields:
        print(f"UNVERIFIED: parsed only {r.fields} runtime_deps fields", file=sys.stderr)
        return 2

    n = len(importers)
    lines = []
    if problems:
        lines.append(f"## libgcc dlopen guard: {len(problems)}/{n} importer(s) FAIL ({r.fields} runtime_deps)\n")
        lines.append(
            "glibc dlopens libgcc_s.so.1 for pthread_cancel/pthread_exit/thrd_exit (aborts without it) "
            "and backtrace (no frames). A dlopen is not DT_NEEDED, so missing-runtime_deps cannot see it.\n"
        )
        for pkg in sorted(problems):
            lines.append(f"- {problems[pkg]}")
            print(f"::error title=libgcc dlopen guard ({pkg})::{problems[pkg]}")
    else:
        lines.append(f"## libgcc dlopen guard: PASS ({n} importers, {r.fields} runtime_deps)\n")
    text = "\n".join(lines) + "\n"
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(text)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
