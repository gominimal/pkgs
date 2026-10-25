#!/usr/bin/env python3
"""llvm-collision guard: no closure may hold two UNPREFIXED LLVM providers.

`llvm` and `llvm-bootstrap` both install LLVM into /usr: usr/bin/clang,
usr/lib/clang/<N>/**, usr/lib/cmake/{llvm,clang}/*.cmake, usr/include/llvm*.
A session (or build sandbox) hardlinks every closure member's files into one
tree, and a path present in two members resolves silently (lowest spec hash
wins), so two unprefixed LLVMs in one closure blend headers, cmake exports and
the clang resource dir from different releases. Nothing fails loudly. The
ruby-flavor guard (ruby_flavor_guard.py) closes the same hazard for Ruby; this
guard has its shape.

Versioned lines (`llvm-22`, `llvm-23`, ...) install under /usr/lib/llvm-<N>
only, so they never collide with /usr or with each other. Policy:

  - prefixed + unprefixed in one closure: ALLOWED (disjoint paths; `llvm-22`
    is itself built by `llvm-bootstrap`, and a consumer like zig may sit next
    to the default `llvm`);
  - two prefixed lines in one closure: ALLOWED (distinct prefixes);
  - two unprefixed providers in one closure: FAIL.

Rules:

  1. prefix   A package named `llvm-<N>` must declare every output under
              usr/lib/llvm-<N>/. One that doesn't is unprefixed and counts as
              a provider for rule 2 as well.
  2. closure  A package's or collection's runtime closure (what a session
              gets) or build closure (build deps plus their runtime closures,
              what a build sandbox gets) holds more than one unprefixed
              provider. Providers are UNPREFIXED plus any package whose output
              globs name LLVM's /usr paths (LLVM_PATH_GLOB), so a copy under a
              new name is caught without editing this file.

Input: `mip dump -p --format json --arch <arch>` output, one file per arch.

Exit codes: 0 = PASS, 1 = violations found, 2 = UNVERIFIED (missing, empty, or
unparseable dump). 2 is deliberately non-zero: a guard that cannot see the
catalog must not report success.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

UNPREFIXED = frozenset({"llvm", "llvm-bootstrap"})
VERSIONED_NAME = re.compile(r"^llvm-(\d+)$")
# An output glob that installs into LLVM's unprefixed /usr layout.
LLVM_PATH_GLOB = re.compile(
    r"^usr/(?:bin/(?:clang|llvm-|ld\.lld)"
    r"|lib/(?:clang/|cmake/(?:llvm|clang|lld)/|lib(?:LLVM|clang))"
    r"|include/(?:llvm|clang|lld))"
)


def dep_name(dep: dict) -> str | None:
    """The package a dep entry points at, whole package or subset."""
    if dep.get("type") == "package":
        return dep.get("name")
    if dep.get("type") == "subset_of":
        return dep.get("package")
    return None


def output_globs(pkg: dict) -> list[str]:
    outs = pkg.get("outputs") or {}
    values = outs.values() if isinstance(outs, dict) else outs
    globs = []
    for out in values:
        if isinstance(out, dict):
            glob = (out.get("value") or {}).get("glob") or out.get("glob")
            if glob:
                globs.append(glob)
    return globs


def unprefixed_globs(pkg: dict) -> list[str]:
    """For an `llvm-<N>` package, the output globs that escape usr/lib/llvm-<N>/."""
    m = VERSIONED_NAME.match(pkg.get("name") or "")
    if not m:
        return []
    prefix = f"usr/lib/llvm-{m.group(1)}/"
    return [g for g in output_globs(pkg) if not g.startswith(prefix)]


def is_provider(pkg: dict) -> bool:
    name = pkg.get("name")
    if name in UNPREFIXED:
        return True
    if VERSIONED_NAME.match(name or ""):
        return bool(unprefixed_globs(pkg))
    return any(LLVM_PATH_GLOB.match(g) for g in output_globs(pkg))


def load(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict):  # tolerate a {name: spec} shape
        data = [dict(v, name=k) for k, v in data.items()]
    if not isinstance(data, list) or not data:
        raise ValueError(f"{path}: expected a non-empty list of packages")
    return data


def runtime_closure(name: str, by_name: dict[str, dict], memo: dict) -> frozenset[str]:
    """`name` plus everything reachable through runtime_deps."""
    if name in memo:
        return memo[name]
    memo[name] = frozenset({name})  # cycle guard; replaced below
    seen = {name}
    for dep in (by_name.get(name) or {}).get("runtime_deps") or []:
        d = dep_name(dep)
        if d:
            seen |= runtime_closure(d, by_name, memo)
    memo[name] = frozenset(seen)
    return memo[name]


def check(pkg: dict, by_name: dict[str, dict], memo: dict, providers: frozenset[str]) -> list[str]:
    name = pkg.get("name", "?")
    problems = []
    escaped = unprefixed_globs(pkg)
    if escaped:
        m = VERSIONED_NAME.match(name)
        problems.append(
            f"prefix: outputs outside usr/lib/llvm-{m.group(1)}/: {', '.join(escaped)}"
        )
    found = sorted(providers & runtime_closure(name, by_name, memo))
    if len(found) > 1:
        problems.append(
            f"closure: runtime closure holds {len(found)} unprefixed LLVM providers: {', '.join(found)}"
        )
    build: set[str] = set()
    for dep in pkg.get("build_deps") or []:
        d = dep_name(dep)
        if d:
            build |= runtime_closure(d, by_name, memo)
    found = sorted(providers & build)
    if len(found) > 1:
        problems.append(
            f"closure: build closure holds {len(found)} unprefixed LLVM providers: {', '.join(found)}"
        )
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
        providers = frozenset(p.get("name") for p in pkgs if is_provider(p))
        if not providers & UNPREFIXED:
            # The catalog always has `llvm`; not finding it means the dump shape
            # changed and this guard is blind.
            print(f"UNVERIFIED {label}: no unprefixed LLVM provider found ({', '.join(sorted(UNPREFIXED))})")
            return 2
        memo: dict = {}
        for pkg in sorted(pkgs, key=lambda p: p.get("name", "")):
            for problem in check(pkg, by_name, memo, providers):
                print(f"FAIL {label} {pkg.get('name')}: {problem}")
                failures += 1
        print(f"checked {len(pkgs)} packages in {label}; unprefixed providers: {', '.join(sorted(providers))}")
    if failures:
        print(f"{failures} violation(s)")
        return 1
    print("PASS")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("dumps", nargs="+", help="mip dump -p --format json output, one per arch")
    return run(ap.parse_args().dumps)


if __name__ == "__main__":
    sys.exit(main())
