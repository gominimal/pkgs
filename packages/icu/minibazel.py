#!/usr/bin/env python3
"""icu-minibazel.py ROOT OUT TARGET...: build ICU's cc_binary targets from its own BUILD.bazel files, without Bazel.

ICU's BUILD files use only cc_library/cc_binary with srcs, hdrs, deps, includes, local_defines, linkopts and
glob(include, exclude). They are evaluated as Python with those as stubs; each TARGET's transitive closure is
compiled (C with $CC, C++ with $CXX) and linked to OUT/<name>. ROOT is the repo root (holding icu4c/ and tools/).
"""
import glob as globmod
import os
import subprocess
import sys

root, out, targets = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2]), sys.argv[3:]
CC, CXX = os.environ.get("CC", "gcc"), os.environ.get("CXX", "g++")
CFLAGS = os.environ.get("CFLAGS", "-O2").split()
rules = {}  # "//pkg:name" -> dict


def load_pkg(pkg):
    path = os.path.join(root, pkg, "BUILD.bazel")
    if not os.path.exists(path):
        path = os.path.join(root, pkg, "BUILD")

    def rule(kind):
        def f(name, **kw):
            rules["//%s:%s" % (pkg, name)] = dict(kw, kind=kind, pkg=pkg, name=name)
        return f

    def glob(include, exclude=(), **_):
        got = set()
        for pat in include:
            got.update(os.path.relpath(p, os.path.join(root, pkg))
                       for p in globmod.glob(os.path.join(root, pkg, pat)))
        for pat in exclude:
            got -= {os.path.relpath(p, os.path.join(root, pkg)) for p in globmod.glob(os.path.join(root, pkg, pat))}
        return sorted(got)

    env = {"cc_library": rule("lib"), "cc_binary": rule("bin"), "glob": glob,
           "load": lambda *a, **k: None, "package": lambda **k: None, "exports_files": lambda *a, **k: None}
    exec(compile(open(path).read(), path, "exec"), env)


def get(label, frm):
    if label.startswith(":"):
        label = "//%s%s" % (frm, label)
    if ":" not in label:
        label += ":" + label.rsplit("/", 1)[-1]
    pkg = label[2:].split(":")[0]
    if label not in rules:
        load_pkg(pkg)
    return rules[label]


def closure(label):
    seen, order = set(), []

    def walk(r):
        key = "//%s:%s" % (r["pkg"], r["name"])
        if key in seen:
            return
        seen.add(key)
        for d in r.get("deps", []):
            walk(get(d, r["pkg"]))
        order.append(r)
    walk(get(label, ""))
    return order


os.makedirs(out, exist_ok=True)
for t in targets:
    rs = closure(t)
    incs, objs, links = set(), [], []
    for r in rs:
        for i in r.get("includes", []):
            incs.add(os.path.normpath(os.path.join(root, r["pkg"], i)))
        incs.add(os.path.join(root, r["pkg"]))
        links += r.get("linkopts", [])
    inc = ["-I" + i for i in sorted(incs)]
    for r in rs:
        defs = ["-D" + d for d in r.get("local_defines", [])]
        for s in r.get("srcs", []):
            if not s.endswith((".c", ".cpp", ".cc")):
                continue
            src = os.path.join(root, r["pkg"], s)
            o = os.path.join(out, "obj", r["pkg"], s + ".o")
            os.makedirs(os.path.dirname(o), exist_ok=True)
            if o in objs:  # a source listed by more than one cc_library (Bazel links archives; we link objects)
                continue
            if not os.path.exists(o):
                cmd = ([CC] if s.endswith(".c") else [CXX, "-std=c++17"]) + CFLAGS + defs + inc + ["-c", src, "-o", o]
                subprocess.run(cmd, check=True)
            objs.append(o)
    name = t.rsplit(":", 1)[-1] if ":" in t else t.rsplit("/", 1)[-1]
    subprocess.run([CXX] + objs + ["-o", os.path.join(out, name)] + sorted(set(links)) + ["-lpthread", "-ldl"], check=True)
    print("built %s from %d rules, %d objects" % (t, len(rs), len(objs)))
