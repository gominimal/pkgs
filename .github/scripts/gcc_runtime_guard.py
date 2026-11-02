#!/usr/bin/env python3
"""gcc-runtime guard: nothing takes gcc at runtime except through gcc-libs.

In minimal a slice does not limit the runtime closure: `subsetOf gcc ["libgcc"]`
carries gcc's WHOLE runtime_deps into the consumer (a Subset edge recurses with
the full spec; minimal crates/graph/src/transitives.rs). gcc's runtime_deps are
what a compiler needs (binutils, glibc, linux_headers, gmp, ...), so a slice of
gcc puts a modern `as`/`ld` into every closure that only wanted libgcc_s or
libstdc++. When the amd64 hex0 ladder is on, that includes the stage0 rungs'
host tools (coreutils -> gmp, bash -> ncurses), and binutils-2.46's gas next to
the ladder's binutils-2.30 broke stage0-gcc-4.7.4 (gominimal/pkgs#805).

gcc-libs (packages/gcc-libs) re-exports gcc's runtime libraries with gcc as a
BUILD dep only, so its consumers' closures stop at glibc. This guard keeps it
that way:

  1. slice    No package's runtime_deps may name gcc, whole or as a subset,
              unless it is in GCC_RUNTIME_ALLOWED. Use
              `subsetOf gcc-libs [...]` for the libraries, or `toolchain` for a
              package that drives the compiler at runtime.
  2. host     The ladder's host tools (LADDER_HOST_TOOLS, plus every non-rung
              build dep of a rung in the dump) must not reach gcc, binutils or
              linux_headers through their runtime closure. While
              packages/hex0/amd64-ladder.ncl is off the rungs are empty stubs,
              so the fixed list is what keeps this rule meaningful.

Input: `minimal dump -p --format json --arch <arch>` output, one file per arch.

Exit codes: 0 = PASS, 1 = violations found, 2 = UNVERIFIED (missing, empty, or
unparseable dump, or no gcc-libs in it). 2 is deliberately non-zero: a guard
that cannot see the catalog must not report success.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

GCC = "gcc"
LIBS = "gcc-libs"
COMPILER_CLOSURE = ("gcc", "binutils", "linux_headers")

# Rule 1 exceptions: package -> why it takes gcc at runtime. `toolchain` is the
# compiler bundle itself. kani and verus-latest drive gcc at runtime. The rest
# are follow-ups that still take gcc WHOLE at runtime (they predate gcc-libs and
# only want its libraries); move each to `subsetOf gcc-libs [...]` and delete
# its line here.
GCC_RUNTIME_ALLOWED: dict[str, str] = {
    "toolchain": "the compiler bundle (gcc + binutils + glibc + linux_headers)",
    "kani": "runs gcc at runtime to compile its harnesses",
    "verus-latest": "runs gcc at runtime",
    "chromium-bin": "follow-up: wants only gcc's libraries",
    "chromium-headless-shell-bin": "follow-up: wants only gcc's libraries",
    "helix": "follow-up: compiles tree-sitter grammars at runtime? verify before moving",
    "hex-patch": "follow-up: wants only gcc's libraries",
    "nushell": "follow-up: wants only gcc's libraries",
    "uv": "follow-up: wants only gcc's libraries",
    "z3": "follow-up: wants only gcc's libraries",
    "zellij": "follow-up: wants only gcc's libraries",
}

# Rule 2: the build tools the amd64 stage0 rungs take from the tree (derived
# from a ladder-on dump, 2026-11-02). Rungs are recognized by name.
LADDER_HOST_TOOLS = frozenset({
    "bash", "bash-bootstrap", "bison", "bzip2", "coreutils", "diffutils", "file",
    "findutils", "gawk", "gawk-bootstrap", "grep", "gzip", "m4", "make", "patch",
    "perl", "python", "sed", "tar", "xz",
})


def is_rung(name: str) -> bool:
    return name == "hex0" or name.startswith("stage0-")


def dep_name(dep: dict) -> str | None:
    """The package a dep entry points at, whole package or subset."""
    if dep.get("type") == "package":
        return dep.get("name")
    if dep.get("type") == "subset_of":
        return dep.get("package")
    return None


def load(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict):  # tolerate a {name: spec} shape
        data = [dict(v, name=k) for k, v in data.items()]
    if not isinstance(data, list) or not data:
        raise ValueError(f"{path}: expected a non-empty list of packages")
    if not any(p.get("name") == LIBS for p in data):
        raise ValueError(f"{path}: no `{LIBS}` package; is this the right tree?")
    return data


def runtime_closure(name: str, by_name: dict[str, dict], memo: dict) -> frozenset[str]:
    """`name` plus everything reachable through runtime_deps (a subset counts as its whole package).

    A full walk per query, cached only once complete: the runtime graph has cycles (gcc <-> gmp
    on main), and caching a node's partial closure while one of its ancestors is still open would
    drop everything reachable through that ancestor.
    """
    if name in memo:
        return memo[name]
    seen = {name}
    stack = [name]
    while stack:
        cur = stack.pop()
        for dep in (by_name.get(cur) or {}).get("runtime_deps") or []:
            d = dep_name(dep)
            if d and d not in seen:
                seen.add(d)
                stack.append(d)
    memo[name] = frozenset(seen)
    return memo[name]


def host_tools(pkgs: list[dict]) -> set[str]:
    tools = set(LADDER_HOST_TOOLS)
    for p in pkgs:
        if is_rung(p.get("name", "")):
            for dep in p.get("build_deps") or []:
                d = dep_name(dep)
                if d and not is_rung(d):
                    tools.add(d)
    return tools


def check(pkg: dict, by_name: dict[str, dict], memo: dict, tools: set[str]) -> list[str]:
    name = pkg.get("name", "?")
    problems = []
    if name not in GCC_RUNTIME_ALLOWED:
        for dep in pkg.get("runtime_deps") or []:
            if dep_name(dep) == GCC:
                how = "a subset of gcc" if dep.get("type") == "subset_of" else "gcc"
                problems.append(
                    f"slice: runtime_deps takes {how}; use `subsetOf {LIBS} [...]` "
                    f"(or `toolchain` to run the compiler), see GCC_RUNTIME_ALLOWED"
                )
    if name in tools:
        reach = sorted(set(COMPILER_CLOSURE) & runtime_closure(name, by_name, memo))
        if reach:
            problems.append(f"host: ladder host tool's runtime closure reaches {', '.join(reach)}")
    return problems


def run(paths: list[str]) -> int:
    failures = 0
    for path in paths:
        label = os.path.basename(path)
        try:
            pkgs = load(path)
        except (OSError, ValueError) as e:
            print(f"UNVERIFIED {label}: {e}")
            return 2
        by_name = {p.get("name"): p for p in pkgs}
        memo: dict = {}
        tools = host_tools(pkgs)
        for pkg in sorted(pkgs, key=lambda p: p.get("name", "")):
            for problem in check(pkg, by_name, memo, tools):
                print(f"FAIL {label} {pkg.get('name')}: {problem}")
                failures += 1
        print(f"checked {len(pkgs)} packages in {label} ({len(tools)} ladder host tools)")
    if failures:
        print(f"{failures} violation(s)")
        return 1
    print("PASS")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("dumps", nargs="+", help="minimal dump -p --format json output, one per arch")
    return run(ap.parse_args().dumps)


if __name__ == "__main__":
    sys.exit(main())
