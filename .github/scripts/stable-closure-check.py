#!/usr/bin/env python3
"""
stable-closure-check.py — is the runtime closure of a package set already on `stable`?

`stable` is a RUNTIME channel: it must stay dependency-closed under runtime_deps.
You cannot promote X to `stable` unless every package in X's transitive runtime
closure is either already on `stable` or being promoted alongside X.

Mechanism (no minimal source changes):
  * `minimal dump -p --format json --arch <arch>` emits, for the WHOLE catalog,
    each package's runtime_deps by name, plus its `attrs` and `needs` maps. We
    union over arches and BFS the runtime edges from the seed set.
  * That BFS reproduces Transitives::for_toplevels(graph, tops, include_build_deps
    =false) (graph/src/transitives.rs:209; recursion hard-false at :176) — BUT
    ONLY IF we also replicate the engine's `internet` injection: transitives.rs
    (the `if build.abstract_deps.contains_key("internet")` block) pulls every
    `needed_for_internet` package into the runtime closure of any node whose
    `needs` contains `internet`. That edge is NOT in runtime_deps, so we add it
    here — otherwise the closure under-counts and we'd PASS when the engine says
    NOT CLOSED (e.g. promoting `gh`/`curl`/`go` before `ca-certificates`).
  * `stable`'s package set = `git ls-tree -d --name-only origin/stable packages/`
    (basenames; basename == package `name` for all packages today). Or, with
    --stable-worktree, dump a stable checkout for name-exact enumeration.

Exit codes: 0 = PASS (closed) or --no-fail; 1 = NOT CLOSED; 2 = operational error.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from typing import Iterable


def eprint(*a: object) -> None:
    print(*a, file=sys.stderr)


def run(cmd: list[str], cwd: str | None = None, env: dict | None = None) -> str:
    try:
        res = subprocess.run(
            cmd, cwd=cwd, env=env, check=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
    except FileNotFoundError:
        eprint(f"error: command not found: {cmd[0]!r}")
        sys.exit(2)
    except subprocess.CalledProcessError as e:
        eprint(f"error: command failed ({' '.join(cmd)}):\n{e.stderr.strip()}")
        sys.exit(2)
    return res.stdout


# ----- dump: catalog runtime-dep edge set + internet injection inputs --------

def dep_name(ref: dict) -> str | None:
    """Name of a runtime_deps entry. Only `package` and `subset_of` ever appear
    in runtime_deps (cmd_dump.rs pkg_ref_from_runtime_dep)."""
    t = ref.get("type")
    if t == "package":
        return ref.get("name")
    if t == "subset_of":
        return ref.get("package")
    return None  # defensive; sources/local files don't occur in runtime_deps


def dump_packages(minimal_bin: str, cwd: str, arch: str) -> list[dict]:
    env = dict(os.environ, MINIMAL_SCIENCE_MODE="1")
    out = run([minimal_bin, "dump", "-p", "--format", "json", "--arch", arch],
              cwd=cwd, env=env)
    try:
        data = json.loads(out)
    except json.JSONDecodeError as e:
        eprint(f"error: could not parse `minimal dump` JSON for arch {arch}: {e}")
        sys.exit(2)
    if not isinstance(data, list):
        eprint(f"error: unexpected dump shape for arch {arch} (expected a list)")
        sys.exit(2)
    return data


def build_runtime_map(minimal_bin: str, cwd: str, arches: list[str]):
    """Return (runtime, catalog, needs_internet, internet_providers), unioned
    across arches.
      runtime            : name -> set(runtime dep names)
      catalog            : all package names seen
      needs_internet     : names whose `needs` contains `internet`
      internet_providers : names carrying the `needed_for_internet` attr
    Two arches because dump resolves one arch at a time and per-arch source
    selection can hide arch-specific deps; union is the conservative bias."""
    runtime: dict[str, set[str]] = {}
    catalog: set[str] = set()
    needs_internet: set[str] = set()
    internet_providers: set[str] = set()
    for arch in arches:
        for pkg in dump_packages(minimal_bin, cwd, arch):
            name = pkg.get("name")
            if not name:
                continue
            catalog.add(name)
            deps = runtime.setdefault(name, set())
            for ref in pkg.get("runtime_deps") or []:
                dn = dep_name(ref)
                if dn:
                    deps.add(dn)
            # `attrs` and `needs` are top-level maps keyed by name in the dump
            # (cmd_dump.rs: attrs/needs are IndexMap<String, PkgAttr>).
            if "needed_for_internet" in (pkg.get("attrs") or {}):
                internet_providers.add(name)
            if "internet" in (pkg.get("needs") or {}):
                needs_internet.add(name)
    return runtime, catalog, needs_internet, internet_providers


# ----- closure BFS (== for_toplevels(..., include_build_deps=false)) ---------

def runtime_closure(seeds: Iterable[str], runtime: dict[str, set[str]],
                    needs_internet: set[str] = frozenset(),
                    internet_providers: set[str] = frozenset()) -> set[str]:
    seen: set[str] = set()
    stack = list(seeds)
    while stack:
        n = stack.pop()
        if n in seen:
            continue
        seen.add(n)
        for d in runtime.get(n, ()):
            if d not in seen:
                stack.append(d)
        # Engine parity: a node that `needs.internet` drags in every
        # `needed_for_internet` provider as a RUNTIME dep (transitives.rs).
        if n in needs_internet:
            for p in internet_providers:
                if p not in seen:
                    stack.append(p)
    return seen


# ----- stable's package set --------------------------------------------------

def stable_set_lstree(ref: str) -> set[str]:
    out = run(["git", "ls-tree", "-d", "--name-only", ref, "packages/"])
    names = {line.rsplit("/", 1)[-1] for line in out.splitlines() if line.strip()}
    if not names:
        eprint(f"error: `git ls-tree {ref} packages/` returned nothing. "
               f"Fetch it first: git fetch origin stable:refs/remotes/origin/stable")
        sys.exit(2)
    return names


def stable_set_worktree(minimal_bin: str, worktree: str, arches: list[str]) -> set[str]:
    """Name-exact: dump a checked-out stable worktree. Avoids the dir==name
    convention entirely. `worktree` is the repo root of a `git worktree add`
    on origin/stable."""
    _, catalog, _, _ = build_runtime_map(minimal_bin, worktree, arches)
    return catalog


# ----- changed-package detection (PR mode) -----------------------------------

def changed_packages(base: str) -> list[str]:
    out = run(["git", "diff", "--name-only", f"{base}...HEAD", "--", "packages/"])
    names: list[str] = []
    seen: set[str] = set()
    for path in out.splitlines():
        parts = path.split("/")
        if len(parts) >= 2 and parts[0] == "packages":
            nm = parts[1]
            if nm not in seen:
                seen.add(nm)
                names.append(nm)
    return names


# ----- main ------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("packages", nargs="*",
                    help="seed package names (the promotion set). Omit with --changed.")
    ap.add_argument("--changed", metavar="BASE", nargs="?", const="origin/main",
                    help="derive seeds from `git diff BASE...HEAD -- packages/` "
                         "(default BASE=origin/main).")
    ap.add_argument("--minimal-bin", default="minimal")
    ap.add_argument("--repo", default=".",
                    help="repo root where `minimal dump` runs (has packages/, minimal.toml).")
    ap.add_argument("--arch", action="append", dest="arches",
                    help="repeatable; default: amd64 arm64.")
    ap.add_argument("--stable-ref", default="origin/stable")
    ap.add_argument("--stable-worktree", metavar="PATH",
                    help="name-exact stable enumeration: dump this stable worktree "
                         "instead of git ls-tree.")
    ap.add_argument("--format", choices=["text", "json"], default="text")
    ap.add_argument("--no-fail", action="store_true",
                    help="always exit 0 (report-only / non-blocking building-block use).")
    args = ap.parse_args()

    arches = args.arches or ["amd64", "arm64"]

    seeds: list[str] = list(args.packages)
    if args.changed is not None:
        seeds += [s for s in changed_packages(args.changed) if s not in seeds]
    if not seeds:
        # --changed with no changed packages (or any --no-fail run) is normal,
        # not an error: there is simply nothing to check. Exit 0 so the
        # report-only workflow stays green on PRs that touch no packages.
        if args.changed is not None or args.no_fail:
            print("no seed packages (no packages/* changed) -- nothing to check.")
            return 0
        eprint("error: no seed packages (pass names or --changed).")
        return 2

    runtime, catalog, needs_internet, internet_providers = \
        build_runtime_map(args.minimal_bin, args.repo, arches)

    unknown = [s for s in seeds if s not in catalog]
    if unknown:
        eprint(f"warning: seed(s) not in dumped catalog (typo? not a package?): "
               f"{', '.join(sorted(unknown))}")

    closure = runtime_closure(seeds, runtime, needs_internet, internet_providers)

    if args.stable_worktree:
        stable = stable_set_worktree(args.minimal_bin, args.stable_worktree, arches)
        stable_src = f"dump of worktree {args.stable_worktree}"
    else:
        stable = stable_set_lstree(args.stable_ref)
        stable_src = f"git ls-tree {args.stable_ref} packages/"

    seed_set = set(seeds)
    missing = sorted((closure - stable - seed_set))
    on_stable = sorted((closure & stable) - seed_set)
    closed = not missing

    if args.format == "json":
        print(json.dumps({
            "seeds": sorted(seed_set),
            "arches": arches,
            "stable_source": stable_src,
            "closure": sorted(closure),
            "on_stable": on_stable,
            "missing": missing,
            "closed": closed,
        }, indent=2))
    else:
        print("=== stable runtime-closure check ===")
        print(f"seeds (promotion set): {', '.join(sorted(seed_set))}")
        print(f"arches: {', '.join(arches)}   catalog packages: {len(catalog)}")
        print(f"stable set via: {stable_src}  ({len(stable)} packages)")
        print()
        print(f"transitive RUNTIME closure ({len(closure)}):")
        print("  " + ", ".join(sorted(closure)))
        print()
        print(f"already on stable ({len(on_stable)}):")
        print("  " + (", ".join(on_stable) or "(none)"))
        print()
        print(f"MISSING from stable ({len(missing)}) — must be promoted alongside:")
        print("  " + (", ".join(missing) or "(none)"))
        print()
        if closed:
            print("VERDICT: PASS — `stable` already satisfies the runtime closure.")
        else:
            print(f"VERDICT: NOT CLOSED — {len(missing)} runtime dep(s) absent from `stable`.")

    if closed or args.no_fail:
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
