#!/usr/bin/env python3
"""ruby-flavor guard: no closure may hold two Ruby lines (gominimal/pkgs#992).

`ruby`, `ruby-3.3` and `ruby-3.4` all install the same paths: usr/bin/ruby,
usr/lib/ruby/**, libruby.so and usr/etc/gemrc. A session (or build sandbox)
hardlinks every closure member's files into one tree, first-writer-wins PER
FILE, so two Ruby lines in one closure blend into an interpreter whose stdlib,
libruby and gems come from different releases. Nothing fails loudly; it just
misbehaves. This is the same hazard the node-runtime guard
(node_runtime_guard.py) closes for npm, and this guard has the same shape:

  1. flavor   A package builds or runs on a versioned line (`ruby-3.3`,
              `ruby-3.4`) instead of `ruby`. One flavor across the catalog
              means every package that needs Ruby brings the SAME interpreter,
              so a user who adds `ruby-lsp` or `bun` gets the `ruby` they
              already have. The versioned lines stay in the catalog as explicit
              USER opt-ins, like `node` (Current). A package that genuinely
              needs one goes in VERSIONED_ALLOWED with the reason.
  2. closure  A package's or collection's closure holds more than one Ruby
              line. Checked for the runtime closure (what a session gets) and
              the build closure (build deps plus their runtime closures, what a
              build sandbox gets). Collections (stacks) are checked too: a stack
              that names `ruby-3.4` next to `ruby-lsp` puts two rubies in one
              session.

Not covered: a user's own loadout (the packages list in their project's
minimal.toml) never reaches this catalog, so `ruby-3.4` + `ruby-lsp` chosen
there is invisible to pkgs CI. Rule 1 keeps every packaged tool on `ruby`, so
the collision needs the user to name a versioned line explicitly; catching it
at activation is a minimal-side change.

Input: `minimal dump -p --format json --arch <arch>` output, one file per arch.

Exit codes: 0 = PASS, 1 = violations found, 2 = UNVERIFIED (missing, empty, or
unparseable dump). 2 is deliberately non-zero: a guard that cannot see the
catalog must not report success.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

DEFAULT = "ruby"
RUBIES = frozenset({"ruby", "ruby-3.3", "ruby-3.4"})
# Rule 1 exceptions: package name -> why it cannot use `ruby`. Empty today; a
# new entry needs a reason a reviewer can check (e.g. a gem that does not build
# on the default line yet).
VERSIONED_ALLOWED: dict[str, str] = {}


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


def check(pkg: dict, by_name: dict[str, dict], memo: dict) -> list[str]:
    name = pkg.get("name", "?")
    problems = []
    if not pkg.get("is_collection") and name not in RUBIES and name not in VERSIONED_ALLOWED:
        for field in ("build_deps", "runtime_deps"):
            for dep in pkg.get(field) or []:
                d = dep_name(dep)
                if d in RUBIES and d != DEFAULT:
                    problems.append(
                        f"flavor: {field} uses `{d}`; use `{DEFAULT}` "
                        f"(versioned lines are user opt-ins, see VERSIONED_ALLOWED)"
                    )
    runtime = runtime_closure(name, by_name, memo)
    rubies = sorted(RUBIES & runtime)
    if len(rubies) > 1:
        problems.append(f"closure: runtime closure holds {len(rubies)} Ruby lines: {', '.join(rubies)}")
    build: set[str] = set()
    for dep in pkg.get("build_deps") or []:
        d = dep_name(dep)
        if d:
            build |= runtime_closure(d, by_name, memo)
    rubies = sorted(RUBIES & build)
    if len(rubies) > 1:
        problems.append(f"closure: build closure holds {len(rubies)} Ruby lines: {', '.join(rubies)}")
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
        for pkg in sorted(pkgs, key=lambda p: p.get("name", "")):
            for problem in check(pkg, by_name, memo):
                print(f"FAIL {label} {pkg.get('name')}: {problem}")
                failures += 1
        print(f"checked {len(pkgs)} packages in {label}")
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
