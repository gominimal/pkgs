#!/usr/bin/env python3
"""node-runtime guard: no package may contribute a second npm (gominimal/pkgs#751).

A session (or build sandbox) hardlinks every closure member's files into one
tree, first-writer-wins PER FILE. So if two members ship different files at
the same path, the result is a blend of both that neither upstream ever
produced. For npm that blend cannot load: every `npm`/`npx` dies with "Class
extends value undefined" (#665 in the build sandbox, #751 in user sessions,
where it broke webapp's `npx astro dev` activation hook).

The general check ("no two closure members ship different bytes at one path")
needs built trees. The npm instance of it has two static causes, both visible
in the evaluated catalog, and this guard rejects both:

  1. shared-tree   A package other than a node runtime declares an output under
                   `usr/lib/node_modules`, the tree the runtime's npm lives in.
                   Install into a private `usr/libexec/<pkg>` prefix instead
                   (#370; see vlt/pnpm/cf for the pattern). A package that BUILDS
                   with a node runtime is also rejected for a broad recursive glob
                   whose literal prefix is an ancestor of that tree (`usr/**`,
                   `usr/lib/**`): its npm install could land there and still be
                   shipped. Non-node packages keep their broad globs (11 C
                   libraries use `usr/**`; they never write node_modules).
  2. runtime-npm   A package other than a node runtime takes a node runtime as a
                   RUNTIME dep with its npm: the whole package, or a subset that
                   includes npm/npx/node_modules. Use `subsetOf node ["node"]`
                   (or node-lts): the interpreter is all a `#!/usr/bin/env node`
                   CLI needs. Build deps are exempt; builds need npm.

  3. flavor        A package builds or runs on `node` (Current) instead of
                   `node-lts`. One flavor across the catalog means every package
                   ships the SAME /usr/bin/node, so there is no first-writer race
                   on the interpreter either; `node` is 25.x, an odd line that
                   never becomes LTS (#752 review). `node` stays in the catalog
                   as an explicit USER opt-in. A package that genuinely needs
                   Current goes in CURRENT_ALLOWED with the reason.

Collections (stacks) are exempt from rules 2 and 3: a stack that names a node
runtime IS the user choosing their node, npm included.

Input: `minimal dump -p --format json --arch <arch>` output, one file per arch
(a spec can differ per arch, so check every arch that was dumped).

Exit codes: 0 = PASS, 1 = violations found, 2 = UNVERIFIED (missing, empty, or
unparseable dump). 2 is deliberately non-zero: a guard that cannot see the
catalog must not report success.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

RUNTIMES = frozenset({"node", "node-lts"})
SHARED_TREE = "usr/lib/node_modules"
# Outputs of a node runtime that carry npm. Anything else (the interpreter,
# headers, man pages) cannot contribute a second npm tree.
NPM_OUTPUTS = frozenset({"npm", "npx", "node_modules"})
# Rule 3 exceptions: package name -> why it cannot use node-lts. Empty today;
# a new entry needs a reason a reviewer can check (e.g. an `engines` floor
# above the current LTS line).
CURRENT_ALLOWED: dict[str, str] = {}


def dep_runtime(dep: dict) -> str | None:
    """The node runtime a dep entry points at, whole package or subset."""
    if dep.get("type") == "package" and dep.get("name") in RUNTIMES:
        return dep["name"]
    if dep.get("type") == "subset_of" and dep.get("package") in RUNTIMES:
        return dep["package"]
    return None


def load(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict):  # tolerate a {name: spec} shape
        data = [dict(v, name=k) for k, v in data.items()]
    if not isinstance(data, list) or not data:
        raise ValueError(f"{path}: expected a non-empty list of packages")
    return data


def literal_dir(glob: str) -> str:
    """The directory part of `glob` before its first wildcard, no trailing /.
    "usr/lib/**" -> "usr/lib"; "usr/**" -> "usr"; "usr/bin/x" -> "usr/bin"."""
    cut = min((i for i, c in enumerate(glob) if c in "*?[{"), default=len(glob))
    lit = glob[:cut]
    if cut == len(glob):  # no wildcard: a literal path; its directory is the parent
        return lit.rstrip("/").rpartition("/")[0] if "/" in lit.rstrip("/") else ""
    return lit.rpartition("/")[0]


def is_ancestor(parent: str, path: str) -> bool:
    return parent == "" or path == parent or path.startswith(parent + "/")


def output_globs(pkg: dict) -> list[tuple[str, str]]:
    out = []
    for key, o in (pkg.get("outputs") or {}).items():
        glob = ((o or {}).get("value") or {}).get("glob")
        if isinstance(glob, str):
            out.append((key, glob))
    return out


def check(pkg: dict) -> list[str]:
    name = pkg.get("name", "?")
    if name in RUNTIMES:
        return []
    problems = []
    builds_with_node = any(dep_runtime(d) for d in pkg.get("build_deps") or [])
    for key, glob in output_globs(pkg):
        g = glob.lstrip("/")
        if g == SHARED_TREE or g.startswith(SHARED_TREE + "/"):
            problems.append(
                f"shared-tree: output `{key}` = \"{glob}\" writes into the node runtime's "
                f"{SHARED_TREE}; install into usr/libexec/{name}/ instead"
            )
        elif builds_with_node and "**" in g and is_ancestor(literal_dir(g), SHARED_TREE):
            problems.append(
                f"shared-tree: output `{key}` = \"{glob}\" is broad enough to capture "
                f"{SHARED_TREE}, and this package builds with node; name a private "
                f"usr/libexec/{name}/** glob instead"
            )
    if not pkg.get("is_collection"):
        for dep in pkg.get("runtime_deps") or []:
            kind = dep.get("type")
            if kind == "package" and dep.get("name") in RUNTIMES:
                problems.append(
                    f"runtime-npm: runtime_deps takes the whole `{dep['name']}` package "
                    f"(npm included); use `subsetOf {dep['name']} [\"node\"]`"
                )
            elif kind == "subset_of" and dep.get("package") in RUNTIMES:
                bad = sorted(NPM_OUTPUTS.intersection(dep.get("outputs") or []))
                if bad:
                    problems.append(
                        f"runtime-npm: runtime_deps subset of `{dep['package']}` includes "
                        f"{bad}; take [\"node\"] only"
                    )
        if name not in CURRENT_ALLOWED:
            for field in ("build_deps", "runtime_deps"):
                if any(dep_runtime(d) == "node" for d in pkg.get(field) or []):
                    problems.append(
                        f"flavor: {field} uses `node` (Current); use `node-lts` "
                        f"(or add {name} to CURRENT_ALLOWED with the reason)"
                    )
    return problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("dumps", nargs="+", help="minimal dump -p --format json output, one per arch")
    args = ap.parse_args(argv)

    # name -> problem -> arches it was seen on (one line per problem, not per arch)
    findings: dict[str, dict[str, set[str]]] = {}
    total = 0
    for path in args.dumps:
        try:
            pkgs = load(path)
        except (OSError, ValueError) as e:
            print(f"UNVERIFIED: cannot read dump: {e}", file=sys.stderr)
            return 2
        total = max(total, len(pkgs))
        arch = os.path.splitext(os.path.basename(path))[0]
        for pkg in pkgs:
            for p in check(pkg):
                findings.setdefault(pkg.get("name", "?"), {}).setdefault(p, set()).add(arch)

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    lines = []
    if findings:
        lines.append(f"## node-runtime guard: {len(findings)} package(s) FAIL (of {total})\n")
        lines.append("A second npm in a closure blends into an unloadable tree (#665, #751).\n")
        for name in sorted(findings):
            for p, arches in sorted(findings[name].items()):
                where = ", ".join(sorted(arches))
                lines.append(f"- `{name}`: {p} [{where}]")
                print(f"::error title=node-runtime guard ({name})::{p} [{where}]")
    else:
        lines.append(f"## node-runtime guard: PASS ({total} packages)\n")
    text = "\n".join(lines) + "\n"
    print(text)
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(text)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
