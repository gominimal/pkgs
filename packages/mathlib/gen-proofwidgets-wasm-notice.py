#!/usr/bin/env python3
"""Generate proofwidgets-penrose-wasm-NOTICE.txt: the third-party notices for
the Rust code compiled into the Penrose optimizer WebAssembly that two of
ProofWidgets' prebuilt widget bundles embed.

Why: ProofWidgets' widget/js/penroseCanvas.js and penroseDisplay.js bundle
@penrose/optimizer, whose dist/index.js carries a Rust cdylib compiled to
wasm32-unknown-unknown as a base64 string. The mathlib package ships those
bundles inside ProofWidgets' .olean files (`include_str`), so it
redistributes that object code. The npm tarball ships no licence file at
all, and gen-proofwidgets-notice.py (which reads npm tarballs) cannot see the
crates inside the blob: nalgebra, serde, wasm-bindgen, ..., plus the Rust
standard library and its registry dependencies (dlmalloc, hashbrown,
compiler_builtins, ...) that rustc links into every wasm32 binary
(pkgs#1244 review).

Run it on a maintainer host (NOT in the build) whenever ProofWidgets or its
@penrose/optimizer is bumped, and commit the output beside build.ncl:

    python3.11 -I gen-proofwidgets-wasm-notice.py \\
        <ProofWidgets4 checkout> <ProofWidgets commit sha> \\
        <penrose checkout at the @penrose/optimizer release tag> \\
        <that penrose commit sha> \\
        <fresh empty download dir> \\
        > proofwidgets-penrose-wasm-NOTICE.txt

What it checks, and refuses to write anything on any failure:
  1. The @penrose/optimizer tarball named by widget/package-lock.json
     (registry.npmjs.org only, sha512 `integrity` verified) embeds exactly one
     wasm module, and every widget/js/*.js that embeds a base64 wasm module
     embeds that same module byte for byte. The penrose checkout's
     packages/optimizer/Cargo.toml has the npm version.
  2. The crate set is computed from the penrose checkout's Cargo.lock: the
     closure of NORMAL dependencies of the cdylib for wasm32-unknown-unknown,
     read from each crate's own Cargo.toml (build-dependencies, dev-
     dependencies, non-matching target sections and proc-macro crates do not
     reach the binary and are excluded; a proc-macro's own dependencies run
     on the host only). Every .crate comes from static.crates.io and is
     verified against the lockfile's sha256 `checksum`.
  3. The Rust standard library's registry crates are pinned per rustc
     version in RUST_STD below; the wasm's `producers` section must name that
     rustc, so a penrose rebuild with another toolchain fails here.
  4. INDEPENDENT WITNESS: the wasm's `name` section lists every function the
     linker kept. Each crate root in those names must belong to the computed
     set (or std's), so a crate that reached the binary by some route the
     dependency walk did not model fails the run instead of shipping
     without a notice.
  5. Every crate in the set has licence text: its verified .crate's root
     LICENSE / LICENCE / COPYING / NOTICE / COPYRIGHT files, plus or instead
     of a CURATED text from proofwidgets-wasm-licences/ (byte-pinned by
     sha256, with the upstream URL it was taken from). A crate with neither,
     or a CURATED entry that matches nothing, fails the run.

The output records the sha256 of each bundle it was checked against;
install-licences.sh (run by both packages' build.sh) refuses to package if a
pinned ProofWidgets bundle differs, so a bump cannot ship a stale notice.

Safety: the downloads are untrusted DATA. Nothing from them is executed or
extracted to disk; licence files and Cargo.toml are read out of the
archives in memory. Python 3.11+ stdlib only (tomllib).
"""

from __future__ import annotations

import base64
import hashlib
import io
import json
import os
import re
import sys
import tarfile
import urllib.request

try:
    import tomllib
except ImportError:  # pragma: no cover
    raise SystemExit("needs Python 3.11+ (tomllib)")

USER_AGENT = "gominimal-pkgmgr-agent (+https://github.com/gominimal)"
NPM = "https://registry.npmjs.org/"
CRATES = "https://static.crates.io/crates/"
NPM_PKG = "@penrose/optimizer"
LICENSE_FILE = re.compile(r"^(LICEN[CS]E|COPYING|NOTICE|COPYRIGHT|UNLICENSE)([._-].*)?$", re.I)
CURATED_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "proofwidgets-wasm-licences")
WASM_B64 = re.compile(r'"(AGFzbQ[A-Za-z0-9+/=]{64,})"')

# The target the penrose optimizer is built for (packages/optimizer
# package.json: `cargo build --target=wasm32-unknown-unknown --release`), as
# cfg() sees it.
TARGET = "wasm32-unknown-unknown"
CFG = {
    "target_arch": "wasm32", "target_os": "unknown", "target_family": "wasm",
    "target_vendor": "unknown", "target_env": "", "target_pointer_width": "32",
    "target_endian": "little",
}
CFG_FLAGS = {"wasm"}  # bare cfg names that are true (`unix`, `windows` are not)

# The Rust standard library as linked into a wasm32-unknown-unknown binary,
# per rustc release (the wasm's `producers` section names it). core, alloc,
# std, panic_abort, unwind and std_detect are Rust-project crates covered by
# Rust's own COPYRIGHT / LICENSE-* texts. The registry crates are std's
# unconditional normal dependencies for this target, from library/std,
# library/alloc and library/core Cargo.toml at the rustc commit, with
# versions and checksums from that commit's Cargo.lock. std's optional
# `backtrace` dependencies (addr2line, gimli, object, miniz_oxide, adler,
# memchr) are not listed: the wasm32-unknown-unknown backtrace is the
# unsupported stub, and check 4 would fail the run if any of their code
# were in the binary.
RUST_STD = {
    "1.71.1 (eb26296b5 2023-08-03)": dict(
        commit="eb26296b556cef10fb713a38f3d16b9886080f26",
        texts=[
            ("rust-1.71.1-COPYRIGHT", "bd0581fef622b3d8b25836cf70feb7e1a7a6171ea9e440b46dfda74c46a0ed0d", "COPYRIGHT"),
            ("rust-1.71.1-LICENSE-APACHE", "62c7a1e35f56406896d7aa7ca52d0cc0d272ac022b5d2796e7d6905db8a3636a", "LICENSE-APACHE"),
            ("rust-1.71.1-LICENSE-MIT", "23f18e03dc49df91622fe2a76176497404e46ced8a715d9d2b67a7446571cca3", "LICENSE-MIT"),
        ],
        lib_roots={"core", "alloc", "std", "panic_abort", "unwind", "std_detect"},
        crates=[
            ("cfg-if", "1.0.0", "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd"),
            ("compiler_builtins", "0.1.92", "64518f1ae689f74db058bbfb3238dfe6eb53f59f4ae712f1ff4348628522e190"),
            ("dlmalloc", "0.2.3", "a6fe28e0bf9357092740362502f5cc7955d8dc125ebda71dec72336c2e15c62e"),
            ("hashbrown", "0.13.1", "33ff8ae62cd3a9102e5637afc8452c55acf3844001bd5374e0b0bd7b6616c038"),
            ("libc", "0.2.143", "edc207893e85c5d6be840e969b496b53d94cec8be2d501b214f50daa97fa8024"),
            ("rustc-demangle", "0.1.21", "7ef03e0a2b150c7a90d01faf6254c9c48a41e95fb2a8c2ac1c6f0d2b9aefc342"),
        ],
    ),
}

# Crates whose .crate ships no licence file, or whose shipped file does not
# cover what the crate declares. Keyed by (name, version).
#   text:  file under proofwidgets-wasm-licences/ (sha256 pinned)
#   mode:  "replace" (crate ships none) or "add" (shipped beside the crate's own)
#   source: where the text was taken from
#   note:  printed in the entry
NALGEBRA_REPO = "https://github.com/dimforge/nalgebra"
CURATED: dict[tuple[str, str], dict] = {
    ("ts-rs", "6.2.1"): dict(
        text="ts-rs-6.2.1.LICENSE",
        sha256="db7f7f8e7236a2d0b41b855b2501b7b913caebbcda6ce498637a304ad1706ce1",
        mode="replace",
        source="https://github.com/Aleph-Alpha/ts-rs/blob/2120fcb56695653bc7f88de690e2199243a1e602/LICENSE "
               "(the commit the 6.2.1 .crate's .cargo_vcs_info.json names)",
        note="The .crate ships no licence file; Cargo.toml declares MIT.",
    ),
    ("nalgebra", "0.31.1"): dict(
        text="nalgebra-BSD-3-Clause-2013.LICENSE",
        sha256="0027599fb41ad7c0fcc0c46017363d3266da2a79f536a84bee1640cdd013d317",
        mode="add",
        source=f"{NALGEBRA_REPO}/blob/2ab82befe4b2fd8826d307048939902089f48cb3/LICENSE "
               "(the last LICENSE before upstream's relicensing commit d81a895a87e2e5a94a847c8033a7c2cce2fbed9a)",
        note="nalgebra 0.31.1's Cargo.toml declares BSD-3-Clause, but the LICENSE file in the .crate (and "
             "at tag v0.31.1) is Apache-2.0, \"Copyright 2020 Sébastien Crozet\": upstream switched to "
             "Apache-2.0 on 2020-08-19 (d81a895, v0.22.0), an unrelated 2021 commit (7d5cc49) put "
             "BSD-3-Clause back into Cargo.toml, and upstream corrected the metadata to Apache-2.0 in "
             "2023 (bad63b6, \"Fix and clarify license in crate metadata\"). Both texts are reproduced: "
             "the shipped Apache-2.0 LICENSE, and the BSD-3-Clause notice nalgebra carried until the "
             "relicensing, for the declared licence and the code that predates it.",
    ),
    ("dlmalloc", "0.2.3"): dict(
        mode="note",
        note="dlmalloc's src/dlmalloc.rs is a Rust port of Doug Lea's dlmalloc, whose source (bundled in the "
             ".crate as src/dlmalloc.c, not compiled for wasm) says, verbatim: \"This is a version (aka "
             "dlmalloc) of malloc/free/realloc written by Doug Lea and released to the public domain, as "
             "explained at http://creativecommons.org/publicdomain/zero/1.0/\".",
    ),
}


def fetch(url: str, dest: str, allowed: str) -> bytes:
    if not url.startswith(allowed):
        raise SystemExit(f"refusing URL outside {allowed}: {url}")
    if os.path.exists(dest):
        with open(dest, "rb") as f:
            return f.read()
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
    with open(dest, "wb") as f:
        f.write(data)
    return data


def sha256(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def norm(text: str) -> str:
    return text.replace("\r\n", "\n").rstrip() + "\n"


# --- wasm --------------------------------------------------------------------

def leb(b: bytes, i: int) -> tuple[int, int]:
    r = s = 0
    while True:
        x = b[i]
        i += 1
        r |= (x & 0x7F) << s
        s += 7
        if x < 0x80:
            return r, i


def wasm_sections(b: bytes) -> tuple[list[str], str]:
    """(function names from the `name` section, rustc from `producers`)."""
    if b[:8] != b"\0asm\x01\0\0\0":
        raise SystemExit("embedded blob is not a wasm module")
    i, names, rustc = 8, [], None
    while i < len(b):
        sid = b[i]
        sz, i = leb(b, i + 1)
        end = i + sz
        if sid == 0:
            nl, j = leb(b, i)
            nm = b[j:j + nl].decode()
            j += nl
            if nm == "name":
                while j < end:
                    sub = b[j]
                    ssz, j = leb(b, j + 1)
                    if sub == 1:
                        cnt, k = leb(b, j)
                        for _ in range(cnt):
                            _idx, k = leb(b, k)
                            ln, k = leb(b, k)
                            names.append(b[k:k + ln].decode("utf-8", "replace"))
                            k += ln
                    j += ssz
            elif nm == "producers":
                fields, k = leb(b, j)
                for _ in range(fields):
                    ln, k = leb(b, k)
                    fname = b[k:k + ln].decode()
                    k += ln
                    vals, k = leb(b, k)
                    for _ in range(vals):
                        ln, k = leb(b, k)
                        tool = b[k:k + ln].decode()
                        k += ln
                        ln, k = leb(b, k)
                        ver = b[k:k + ln].decode()
                        k += ln
                        if fname == "processed-by" and tool == "rustc":
                            rustc = ver
        i = end
    if not names:
        raise SystemExit("wasm has no function `name` section; cannot cross-check its crates")
    if not rustc:
        raise SystemExit("wasm `producers` section names no rustc")
    return names, rustc


# A path root: an identifier followed by `::` that does not itself follow
# `::` (so `core::fmt::write` yields `core`, `<serde::de::X as Y>` `serde`).
ROOT = re.compile(r"(?<![A-Za-z0-9_:])([A-Za-z_][A-Za-z0-9_]*)::")


def name_roots(names: list[str]) -> set[str]:
    roots = set()
    for n in names:
        roots.update(ROOT.findall(n))
    return roots


def embedded_wasms(js: str) -> list[bytes]:
    return [base64.b64decode(m.group(1)) for m in WASM_B64.finditer(js)]


# --- cargo -------------------------------------------------------------------

def cfg_eval(expr: str) -> bool:
    toks: list[str] = []
    pos = 0

    def pred() -> bool:
        nonlocal pos
        t = toks[pos]
        pos += 1
        if t in ("all", "any", "not"):
            assert toks[pos] == "("
            pos += 1
            vals = []
            while toks[pos] != ")":
                vals.append(pred())
                if toks[pos] == ",":
                    pos += 1
            pos += 1
            if t == "all":
                return all(vals)
            if t == "any":
                return any(vals)
            if len(vals) != 1:
                raise SystemExit(f"bad cfg {expr!r}")
            return not vals[0]
        if pos < len(toks) and toks[pos] == "=":
            v = toks[pos + 1].strip('"')
            pos += 2
            if t == "target_feature":
                return False
            if t not in CFG:
                raise SystemExit(f"cfg key {t!r} in {expr!r} is not modelled; extend CFG")
            return CFG[t] == v
        return t in CFG_FLAGS

    m = re.fullmatch(r"\s*cfg\((.*)\)\s*", expr)
    if not m:
        return expr == TARGET  # a plain target triple
    toks = re.findall(r'[A-Za-z_][A-Za-z0-9_]*|"[^"]*"|[(),=]', m.group(1))
    return pred()


def normal_deps(manifest: dict) -> set[str]:
    """Package names this manifest depends on normally when built for TARGET."""
    out = set()

    def add(table: dict):
        for key, spec in (table or {}).items():
            out.add(spec.get("package", key) if isinstance(spec, dict) else key)

    add(manifest.get("dependencies"))
    for expr, sect in (manifest.get("target") or {}).items():
        if cfg_eval(expr):
            add(sect.get("dependencies"))
    return out


def all_declared(manifest: dict) -> set[str]:
    out = set()
    for sect in [manifest] + list((manifest.get("target") or {}).values()):
        for kind in ("dependencies", "build-dependencies", "dev-dependencies"):
            for key, spec in (sect.get(kind) or {}).items():
                out.add(spec.get("package", key) if isinstance(spec, dict) else key)
    return out


def read_crate(data: bytes, name: str, ver: str) -> tuple[dict, list[tuple[str, str]]]:
    root = f"{name}-{ver}/"
    manifest, files = None, []
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf:
        for m in tf.getmembers():
            if not m.isfile() or not m.name.startswith(root):
                continue
            rel = m.name[len(root):]
            if rel == "Cargo.toml":
                manifest = tomllib.loads(tf.extractfile(m).read().decode("utf-8"))
            elif "/" not in rel and LICENSE_FILE.match(rel):
                files.append((rel, norm(tf.extractfile(m).read().decode("utf-8", "replace"))))
    if manifest is None:
        raise SystemExit(f"{name}-{ver}.crate has no {root}Cargo.toml")
    return manifest, sorted(files)


def get_crate(name: str, ver: str, checksum: str, dl: str) -> bytes:
    data = fetch(f"{CRATES}{name}/{name}-{ver}.crate", os.path.join(dl, f"{name}-{ver}.crate"), CRATES)
    if sha256(data) != checksum:
        raise SystemExit(f"{name}-{ver}.crate: sha256 {sha256(data)} != Cargo.lock checksum {checksum}")
    return data


def lock_packages(lock: dict) -> dict[tuple[str, str], dict]:
    return {(p["name"], p["version"]): p for p in lock["package"]}


def resolve_edge(dep: str, pkgs: dict) -> tuple[str, str]:
    parts = dep.split(" ")
    if len(parts) >= 2:
        return parts[0], parts[1]
    cands = [k for k in pkgs if k[0] == parts[0]]
    if len(cands) != 1:
        raise SystemExit(f"Cargo.lock dependency {dep!r} is ambiguous or missing")
    return cands[0]


def curated_text(fname: str, want: str) -> str:
    with open(os.path.join(CURATED_DIR, fname), "rb") as f:
        raw = f.read()
    if sha256(raw) != want:
        raise SystemExit(f"curated {fname}: sha256 {sha256(raw)}, table pins {want}")
    return norm(raw.decode("utf-8"))


# --- main --------------------------------------------------------------------

def main() -> int:
    pw_dir, pw_commit, pen_dir, pen_commit, dl = sys.argv[1:6]
    os.makedirs(dl, exist_ok=True)

    # 1. The npm tarball, its wasm, and the bundles that embed it.
    lock = json.load(open(os.path.join(pw_dir, "widget", "package-lock.json"), "rb"))
    ent = lock["packages"].get(f"node_modules/{NPM_PKG}")
    if not ent:
        raise SystemExit(f"{NPM_PKG} not in widget/package-lock.json")
    npm_ver = ent["version"]
    tgz = fetch(ent["resolved"], os.path.join(dl, f"penrose-optimizer-{npm_ver}.tgz"), NPM)
    algo, _, want = ent["integrity"].partition("-")
    if algo != "sha512" or base64.b64encode(hashlib.sha512(tgz).digest()).decode() != want:
        raise SystemExit(f"{NPM_PKG}@{npm_ver}: tarball does not match lockfile integrity")
    with tarfile.open(fileobj=io.BytesIO(tgz), mode="r:gz") as tf:
        index_js = tf.extractfile("package/dist/index.js").read().decode("utf-8")
    npm_wasms = embedded_wasms(index_js)
    if len(npm_wasms) != 1:
        raise SystemExit(f"{NPM_PKG}@{npm_ver} dist/index.js embeds {len(npm_wasms)} wasm modules, expected 1")
    wasm = npm_wasms[0]

    js_dir = os.path.join(pw_dir, "widget", "js")
    bundles = []
    for fn in sorted(os.listdir(js_dir)):
        if not fn.endswith(".js"):
            continue
        raw = open(os.path.join(js_dir, fn), "rb").read()
        found = embedded_wasms(raw.decode("utf-8", "replace"))
        for w in found:
            if w != wasm:
                raise SystemExit(f"widget/js/{fn} embeds a wasm module (sha256 {sha256(w)}) that is not "
                                 f"{NPM_PKG}@{npm_ver}'s; it needs its own notice")
        if found:
            bundles.append((fn, sha256(raw)))
    if not bundles:
        raise SystemExit(f"no widget/js bundle embeds {NPM_PKG}'s wasm; is this file still needed?")

    names, rustc = wasm_sections(wasm)
    if rustc not in RUST_STD:
        raise SystemExit(f"wasm was built by rustc {rustc!r}; RUST_STD has no entry for it. Add one from "
                         "that rustc commit's library/*/Cargo.toml and Cargo.lock.")
    std = RUST_STD[rustc]

    # 2. The cdylib's normal-dependency closure for TARGET.
    pen_manifest = tomllib.load(open(os.path.join(pen_dir, "packages", "optimizer", "Cargo.toml"), "rb"))
    if pen_manifest["package"]["version"] != npm_ver:
        raise SystemExit(f"penrose checkout's optimizer is {pen_manifest['package']['version']}, npm is {npm_ver}")
    if "cdylib" not in pen_manifest.get("lib", {}).get("crate-type", []):
        raise SystemExit("packages/optimizer is not a cdylib")
    cargo_lock_raw = open(os.path.join(pen_dir, "Cargo.lock"), "rb").read()
    pkgs = lock_packages(tomllib.loads(cargo_lock_raw.decode("utf-8")))
    root = (pen_manifest["package"]["name"], npm_ver)
    if root not in pkgs or "source" in pkgs[root]:
        raise SystemExit(f"{root} is not the workspace package in Cargo.lock")

    crates: dict[tuple[str, str], dict] = {}  # included registry crates
    excluded: dict[tuple[str, str], str] = {}
    queue = [(root, pen_manifest)]
    seen = {root}
    while queue:
        key, manifest = queue.pop()
        normal, declared = normal_deps(manifest), all_declared(manifest)
        for dep in pkgs[key].get("dependencies", []):
            child = resolve_edge(dep, pkgs)
            if child[0] not in declared:
                raise SystemExit(f"Cargo.lock has {key[0]} -> {child[0]}, which {key[0]}'s Cargo.toml does not declare")
            if child in seen:
                continue
            if child[0] not in normal:
                excluded.setdefault(child, f"build/dev or non-{TARGET} dependency of {key[0]}")
                continue
            seen.add(child)
            excluded.pop(child, None)
            p = pkgs[child]
            if p.get("source") != "registry+https://github.com/rust-lang/crates.io-index":
                raise SystemExit(f"{child}: source {p.get('source')!r} is not crates.io")
            data = get_crate(child[0], child[1], p["checksum"], dl)
            cm, files = read_crate(data, *child)
            if cm.get("lib", {}).get("proc-macro"):
                excluded[child] = f"proc-macro (runs in rustc on the host; dependency of {key[0]})"
                continue
            crates[child] = dict(manifest=cm, files=files, origin=f"{key[0]}")
            queue.append((child, cm))
    # Anything else in the lockfile is only reachable through an exclusion.
    for k in pkgs:
        if k != root and k not in crates and k not in excluded:
            excluded[k] = "only reachable through an excluded crate (host-side)"

    std_crates: dict[tuple[str, str], dict] = {}
    for n, v, ck in std["crates"]:
        if (n, v) in crates:  # the same crate on both sides: one entry
            crates[(n, v)]["origin"] += "; also the Rust standard library"
            continue
        data = get_crate(n, v, ck, dl)
        cm, files = read_crate(data, n, v)
        std_crates[(n, v)] = dict(manifest=cm, files=files, origin="Rust standard library")

    # 4. Independent witness: every crate root in the wasm's function names.
    lib_name = lambda m, n: (m.get("lib", {}).get("name") or n).replace("-", "_")
    covered = {lib_name(c["manifest"], k[0]): k for k, c in {**crates, **std_crates}.items()}
    covered[lib_name(pen_manifest, root[0])] = root
    for r in std["lib_roots"]:
        covered[r] = ("rust", rustc)
    roots = name_roots(names)
    # Identifiers that are not crates: generic parameters / Self in paths.
    roots -= {"Self", "T", "A", "D", "R", "S", "F", "K", "V", "I", "E"}
    # Zero roots means ROOT matched nothing (e.g. a rebuild with mangled
    # `_ZN...` names), not that every crate is covered.
    if not roots:
        raise SystemExit("the wasm's name section yields no demangled `crate::` paths, so the witness "
                         "cannot check coverage; extend name_roots to read this name section")
    uncovered = sorted(r for r in roots if r not in covered)
    if uncovered:
        raise SystemExit(f"the wasm's name section has code under {uncovered}, which no notice entry covers; "
                         "find the crate and model how it reaches the binary")
    present = {covered[r] for r in roots}
    print("name-section crate roots: " + " ".join(sorted(roots)), file=sys.stderr)

    # 5. Licence text for every crate.
    used, missing = set(), []
    entries = []
    for k, c in sorted(crates.items()) + sorted(std_crates.items()):
        texts = list(c["files"])
        notes = []
        cur = CURATED.get(k)
        if cur:
            used.add(k)
            if cur.get("note"):
                notes.append(cur["note"])
            if cur["mode"] in ("replace", "add"):
                if cur["mode"] == "replace" and texts:
                    raise SystemExit(f"{k}: CURATED says the .crate ships no licence file, but it ships {[t[0] for t in texts]}")
                if cur["mode"] == "add" and not texts:
                    raise SystemExit(f"{k}: CURATED adds to the .crate's licence files, but it ships none")
                texts.append((f"{cur['text']} (curated)", curated_text(cur["text"], cur["sha256"])))
                notes.append(f"Curated text source: {cur['source']}")
                notes.append(f"Curated text: proofwidgets-wasm-licences/{cur['text']} (sha256 {cur['sha256']})")
        if not texts:
            missing.append(f"{k[0]}-{k[1]} (declared {c['manifest']['package'].get('license')!r})")
        entries.append((k, c, texts, notes))
    stale = sorted(f"{n}-{v}" for (n, v) in CURATED if (n, v) not in used)
    if missing or stale:
        for m in missing:
            print(f"ERROR {m}: the .crate ships no licence file and CURATED has no entry", file=sys.stderr)
        for m in stale:
            print(f"ERROR {m}: CURATED entry matches no crate in this wasm", file=sys.stderr)
        raise SystemExit("nothing written")

    rust_texts = [(f"{up} (Rust {rustc.split()[0]}, rust-lang/rust@{std['commit']})", curated_text(f, h))
                  for f, h, up in std["texts"]]

    w = sys.stdout.write
    w(f"Rust crates in the Penrose optimizer WebAssembly (ProofWidgets4 {pw_commit[:7]})\n")
    w("=" * 76 + "\n\n")
    w(f"ProofWidgets' widget bundles {', '.join(b for b, _ in bundles)} embed\n"
      f"{NPM_PKG} {npm_ver} (rollup), whose dist/index.js carries a Rust\n"
      f"library compiled to {TARGET} as a base64 string. The mathlib\n"
      "package ships those bundles inside ProofWidgets' .olean files (via\n"
      "`include_str`), so it redistributes that object code. Its npm tarball\n"
      "ships no licence file; the crates below are what was compiled into it.\n\n"
      "Generated by packages/mathlib/gen-proofwidgets-wasm-notice.py:\n"
      f"  - the crate set is the normal-dependency closure of penrose's\n"
      f"    `{root[0]}` cdylib for {TARGET}, from penrose's\n"
      "    Cargo.lock and each crate's own Cargo.toml (proc-macro crates and\n"
      "    build- and dev-dependencies run on the build host and are excluded;\n"
      "    they are listed at the end), plus the Rust standard library and its\n"
      "    registry crates for the rustc named in the wasm's `producers` section;\n"
      "  - every .crate is from static.crates.io, verified against its Cargo.lock\n"
      "    sha256 checksum, and licence texts are verbatim from its root\n"
      "    LICENSE / COPYING / NOTICE / COPYRIGHT files (curated upstream text\n"
      "    where a .crate ships none; source and sha256 in the entry);\n"
      "  - cross-checked against the wasm's `name` section: every crate whose\n"
      "    functions the linker kept is in this list (marked [code in wasm]).\n"
      "    Unmarked crates are dependencies whose code was inlined into a\n"
      "    caller or stripped; they are listed because they were compiled in.\n\n"
      "Where a crate is offered under a choice of licences (\"MIT OR Apache-2.0\"),\n"
      "all of the texts it ships are reproduced.\n\n")
    w(f"{NPM_PKG} {npm_ver}: {ent['resolved']}\n")
    w(f"  wasm sha256: {sha256(wasm)}\n")
    w(f"penrose source: https://github.com/penrose/penrose/tree/{pen_commit} (Cargo.lock sha256 {sha256(cargo_lock_raw)})\n")
    w(f"rustc: {rustc} (rust-lang/rust@{std['commit']})\n\n")
    w("These bundles are what this file was checked against. The package build\n"
      "fails if either hash differs, so a ProofWidgets bump forces a re-run:\n\n")
    for fn, h in bundles:
        w(f"{fn} sha256: {h}\n")
    w("\n")

    rows = [("penrose-optimizer", npm_ver, pen_manifest["package"].get("license") or "MIT",
             "penrose (the cdylib itself)", root in present)]
    rows += [(k[0], k[1], c["manifest"]["package"].get("license") or "SEE FILE", f"dependency of {c['origin']}",
              k in present) for k, c in sorted(crates.items())]
    rows.append(("Rust core/alloc/std", rustc.split()[0], "MIT OR Apache-2.0", "Rust standard library", True))
    rows += [(k[0], k[1], c["manifest"]["package"].get("license") or "SEE FILE", c["origin"], k in present)
             for k, c in sorted(std_crates.items())]
    wn = max(len(r[0]) for r in rows)
    wv = max(len(r[1]) for r in rows)
    wl = max(len(r[2]) for r in rows)
    w(f"Compiled in ({len(rows)}):\n\n")
    for n, v, lic, why, pres in rows:
        w(f"  {n.ljust(wn)}  {v.ljust(wv)}  {lic.ljust(wl)}  {'[code in wasm]' if pres else ''}\n")
    w("\n")

    w("-" * 76 + "\n")
    w(f"penrose-optimizer {npm_ver} ({NPM_PKG})\nLicense: MIT\n"
      "Its licence text (penrose's LICENSE at tag v" + npm_ver + ") is in THIRD-PARTY-NOTICES.txt under\n"
      f"{NPM_PKG}@{npm_ver}.\n\n")
    w("-" * 76 + "\n")
    w(f"Rust standard library (core, alloc, std, panic_abort, std_detect, unwind), rustc {rustc}\n"
      "License: MIT OR Apache-2.0\n")
    for fname, text in rust_texts:
        w(f"\n--- {fname} ---\n{text}")
    w("\n")
    for k, c, texts, notes in entries:
        w("-" * 76 + "\n")
        w(f"{k[0]} {k[1]}  (crates.io; {c['origin'] if c['origin'] == 'Rust standard library' else 'dependency of ' + c['origin']})\n")
        w(f"License: {c['manifest']['package'].get('license') or 'see file'}\n")
        for n in notes:
            w(f"Note: {n}\n")
        for fname, text in texts:
            w(f"\n--- {fname} ---\n{text}")
        w("\n")
    w("-" * 76 + "\n")
    w("Not compiled into the wasm (host-side only), from the same Cargo.lock:\n\n")
    for k, why in sorted(excluded.items()):
        w(f"  {k[0]} {k[1]}: {why}\n")
    print(f"{len(crates)} crates + {len(std_crates)} std crates; {len(present)} with code in the name section; "
          f"{len(excluded)} excluded", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
