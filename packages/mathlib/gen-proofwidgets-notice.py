#!/usr/bin/env python3
"""Generate the two third-party files for the npm code bundled into
ProofWidgets' prebuilt widget JavaScript:

  proofwidgets-js-NOTICE.txt       (default mode) verbatim licence texts
  proofwidgets-js-third-party.txt  (--inventory)  one line per package

Why: ProofWidgets commits its infoview JS prebuilt (widget/js/*.js, rollup +
terser), and its .olean files embed it via `include_str`, so the `mathlib`
package redistributes that code. The minified bundles strip almost every
copyright notice that MIT / ISC / BSD require to travel with the code. This
script rebuilds those notices from the exact npm tarballs the pinned
package-lock.json resolves.

Run it on a maintainer host (NOT in the build) whenever ProofWidgets is
bumped, in both modes, then commit both outputs beside build.ncl:

    # NOTICE: name@version, declared licence, verbatim LICENSE/COPYING/NOTICE
    # text from each exact npm tarball.
    python3 -I gen-proofwidgets-notice.py \\
        <ProofWidgets4 checkout>/widget/package-lock.json \\
        <ProofWidgets commit sha> \\
        <fresh empty download dir> \\
        > proofwidgets-js-NOTICE.txt

    # Inventory: name, version, licence, one line each. Read from the
    # lockfile; a package the lockfile gives no licence for is resolved from
    # its (verified) tarball's LICENSE text, so it fetches only those.
    python3 -I gen-proofwidgets-notice.py --inventory \\
        <ProofWidgets4 checkout>/widget/package-lock.json \\
        <ProofWidgets commit sha> \\
        <download dir, may be the one above> \\
        > proofwidgets-js-third-party.txt

Both outputs record `package-lock.json sha256: <hex>`; install-licences.sh
(run by both packages' build.sh) refuses to package if either differs from
the pinned ProofWidgets lockfile, so a stale file cannot ship. Output is deterministic (sorted by name, then version).

Safety: the tarballs are untrusted DATA. Nothing from them is executed or
written to disk except the tarball itself; licence files and package.json are
read out of the archive in memory. Each tarball is verified against the
lockfile's `integrity` (sha512) before it is read. Only registry.npmjs.org
URLs are fetched. Python stdlib only.

Packages with no licence file in their npm tarball: the default mode FAILS
(exit 1, nothing written) for each one that has no entry in CURATED below,
and for each CURATED entry that no longer matches a lockfile package without
a licence file. An entry either names a curated text committed under
proofwidgets-js-licences/ (byte-pinned by sha256, with the upstream URLs it
was taken from) or marks the package a rollup external that is not bundled.
So a ProofWidgets bump that pulls in a new licence-less package cannot ship
its code with only an SPDX id. --inventory likewise FAILS (exit 1, nothing
written) on a package whose licence it cannot resolve from the lockfile,
package.json or a recognised LICENSE text.
"""

from __future__ import annotations

import base64
import fnmatch
import hashlib
import io
import json
import os
import re
import sys
import tarfile
import urllib.request

USER_AGENT = "gominimal-pkgmgr-agent (+https://github.com/gominimal)"
REGISTRY = "https://registry.npmjs.org/"
LICENSE_FILE = re.compile(r"^(LICEN[CS]E|COPYING|NOTICE)([._-].*)?$", re.I)
CURATED_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "proofwidgets-js-licences")

# Curated licence texts for lockfile packages whose npm tarball ships no
# licence file at its root. Keyed by (name, version): a ProofWidgets bump
# that moves one of these to a new version must re-check upstream.
#
#   text:    file under proofwidgets-js-licences/, copied verbatim (sha256 is
#            of that file and is checked on every run)
#   sources: where the text came from, at the commit/tag matching the npm
#            version (two sources where the version has no exact tag)
#   tarball: extra licence files read from the package's own verified npm
#            tarball (fnmatch patterns on member names)
#   note:    printed in the NOTICE entry
#   external: the package is a rollup external, so no code of it is bundled
#
# Where upstream publishes no licence text at all (no file in the repo at the
# release, none in the tarball), the entry carries the SPDX License List's
# standard text for the declared licence and quotes upstream's own licence
# statement verbatim. That is all that exists to reproduce; it says so.
SPDX_SRC = "https://github.com/spdx/license-list-data/blob/31ba1a50e5397e00a304dbadc76531740e89ee48/text/{} (SPDX License List v3.29.0)"
CURATED: dict[tuple[str, str], dict] = {
    ("@bkrem/react-transition-group", "1.3.5"): dict(
        text="bkrem-react-transition-group-1.3.5.LICENSE",
        sha256="8e51db30748ee93e902fdfe36779f5aa935d55c77e7a21c20a27310ebafe10f6",
        sources=[
            "https://github.com/bkrem/react-transition-group/blob/2ee5bf857f4a556d631a556a99058c36496386db/LICENSE (tag v1.3.5, the version npm publishes)",
            "https://github.com/reactjs/react-transition-group/blob/f5ae18965760e509aeca7115a3acf97c85d06d0a/LICENSE (tag v1.2.1 of the v1 line it forks; byte-identical)",
        ],
        note="Fork of reactjs/react-transition-group v1 (itself forked from React's addons); rbTree.js bundles its TransitionGroup/CSSTransitionGroup.",
    ),
    ("@leanprover/infoview", "0.11.0"): dict(
        external="rollup external in widget/rollup.config.js (supplied by the editor's infoview at runtime)",
    ),
    ("@leanprover/infoview-api", "0.11.0"): dict(
        external="dependency of @leanprover/infoview only, which is a rollup external",
    ),
    ("@lit-labs/ssr-dom-shim", "1.5.1"): dict(
        text="lit.LICENSE",
        sha256="45d31799d0db956cc3eb5469346abbd9b7025babc5ff29fab10d7095da992ef1",
        sources=[
            "https://github.com/lit/lit/blob/43c6168acc4a30d70091ee30c307f692a02387d5/LICENSE (tag @lit-labs/ssr-dom-shim@1.4.0)",
            "https://github.com/lit/lit/blob/20afabd3c5bfd49fdcdf1b8518e05c7f99a46db6/LICENSE (tag @lit-labs/ssr-dom-shim@1.6.0; byte-identical)",
        ],
        note="No @lit-labs/ssr-dom-shim@1.5.1 tag exists; the package directory has no LICENSE of its own, so the lit monorepo root's applies (bracketing tags agree).",
    ),
    ("@mediapipe/tasks-vision", "0.10.17"): dict(
        text="mediapipe.LICENSE",
        sha256="8707eef0533987efc5b155d64761eeb6e20793f50b9bd1a68dad1cf4719d0ed8",
        sources=[
            "https://github.com/google-ai-edge/mediapipe/blob/e252e5667e2be398dcc4c5d49ca134248e2111c8/LICENSE (tag v0.10.15)",
            "https://github.com/google-ai-edge/mediapipe/blob/76e52c759f87e6e71f531dd785cd892ba163a454/LICENSE (tag v0.10.18; byte-identical)",
        ],
        note="No v0.10.17 tag exists; the bracketing tags' LICENSE files agree.",
    ),
    ("@penrose/core", "3.2.0"): dict(
        text="penrose-3.2.0.LICENSE",
        sha256="afb11426e09da40a1ae4f8fa17ddcc6b6a52d14df04c29bc5bcd06eb8730624d",
        sources=["https://github.com/penrose/penrose/blob/fd4aae0b95ad6f7b35863de87b16e796e2c3bfda/LICENSE (tag v3.2.0)"],
        note="Upstream's copyright line names no holder; reproduced as published.",
    ),
    ("@penrose/optimizer", "3.2.0"): dict(
        text="penrose-3.2.0.LICENSE",
        sha256="afb11426e09da40a1ae4f8fa17ddcc6b6a52d14df04c29bc5bcd06eb8730624d",
        sources=["https://github.com/penrose/penrose/blob/fd4aae0b95ad6f7b35863de87b16e796e2c3bfda/LICENSE (tag v3.2.0)"],
        note="Same monorepo as @penrose/core. Upstream's copyright line names no holder; reproduced as published.",
    ),
    ("@react-three/fiber", "8.18.0"): dict(
        text="react-three-fiber-8.18.0.LICENSE",
        sha256="ebd6a29bec64bdfcf8795388f2eceaf1479c14d343c0846de347ab8609d66139",
        sources=["https://github.com/pmndrs/react-three-fiber/blob/f81bfe8cb29373d2687433c6130e0ce1daf7222c/LICENSE (tag v8.18.0)"],
    ),
    ("consola", "2.15.3"): dict(
        text="SPDX-MIT.txt",
        sha256="b05785f9f18e6716bab63424b11454513b9943a222595b70411009202fc592b5",
        sources=[SPDX_SRC.format("MIT.txt")],
        note="Upstream publishes no licence file (none in the repo at tag v2.15.3, "
             "unjs/consola@c99ff6c4a54a6a7eccea26aa37603b9b36535d48, nor in the npm tarball). "
             "Its README's licence statement, verbatim: \"MIT - Made with 💖 By Nuxt.js team!\". "
             "Standard MIT text follows; upstream names no copyright holder.",
    ),
    ("draco3d", "1.5.7"): dict(
        text="draco-1.5.7.LICENSE",
        sha256="d3709b0fb4b8a94bbb1d02b8a2e484f258b0d9c5c5a01f940391f3fe662cd1a4",
        sources=["https://github.com/google/draco/blob/8786740086a9f4d83f44aa83badfbea4dce7a1b5/LICENSE (tag 1.5.7)"],
    ),
    ("maath", "0.10.8"): dict(
        text="SPDX-MIT.txt",
        sha256="b05785f9f18e6716bab63424b11454513b9943a222595b70411009202fc592b5",
        sources=[SPDX_SRC.format("MIT.txt")],
        note="Upstream publishes no licence file (none anywhere in the repo at tag maath@0.10.8, "
             "pmndrs/maath@626d198fbae28ba82f2f1b184db7fcafd4d23846, nor in the npm tarball); "
             "its package.json declares \"license\": \"MIT\". (A LICENSE added 2026-08-03, commit "
             "a03a7a4194, \"project boilerplate\", post-dates this 2024 release and is not used.) "
             "Standard MIT text follows; upstream names no copyright holder for this release.",
    ),
    ("mj-context-menu", "0.6.1"): dict(
        text="SPDX-Apache-2.0.txt",
        sha256="074e6e32c86a4c0ef8b3ed25b721ca23aca83df277cd88106ef7177c354615ff",
        sources=[SPDX_SRC.format("Apache-2.0.txt")],
        note="Upstream publishes no licence file (none in the repo at tag v0.6.1, "
             "zorkow/context-menu@e44c1eaa3fe202af467557c01eee68b86410dcce, nor in the npm tarball) "
             "and no NOTICE; its package.json declares \"license\": \"Apache-2.0\". "
             "Apache-2.0 s4(a) asks for a copy of the licence, which follows.",
    ),
    ("railroad-diagrams", "1.0.0"): dict(
        text="SPDX-CC0-1.0.txt",
        sha256="a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499",
        sources=[SPDX_SRC.format("CC0-1.0.txt")],
        note="The 1.0.0 npm tarball has no licence file; its README.md says, verbatim: "
             "\"This document and all associated files in the github project are licensed under "
             "[CC0](http://creativecommons.org/publicdomain/zero/1.0/)\". (The repo's later "
             "MIT LICENSE was added 2022-01-18, commit 3e08ad2b7b, after this 2015 release.) "
             "CC0 text follows.",
    ),
    ("seedrandom", "3.0.5"): dict(
        text="seedrandom-3.0.5.README-excerpt",
        sha256="7500bc57d010cde21006d88014d7191f36be1750894bfc4a01ce3844f1f9af2e",
        sources=["https://github.com/davidbau/seedrandom/blob/4460ad325a0a15273a211e509f03ae0beb99511a/README.md#L299-L321 (tag 3.0.5)"],
        note="Upstream has no licence file; the MIT notice is README.md's LICENSE section "
             "(lines 299-321 at tag 3.0.5, the same text that heads seedrandom.js), excerpted verbatim.",
    ),
    ("stats-gl", "2.4.2"): dict(
        text="SPDX-MIT.txt",
        sha256="b05785f9f18e6716bab63424b11454513b9943a222595b70411009202fc592b5",
        sources=[SPDX_SRC.format("MIT.txt")],
        note="Upstream publishes no licence file (GitHub reports no commit ever touching LICENSE; "
             "main is RenaudRohlinger/stats-gl@dae82f5a4a14d19a3ec21bc47b28a491a668a036; there is no 2.4.2 tag; "
             "none in the npm tarball). Its README says, verbatim: \"This project is licensed under the "
             "MIT License.\"; package.json author: Renaud ROHLINGER. Standard MIT text follows.",
    ),
    ("victory-vendor", "36.9.2"): dict(
        text="victory-36.9.2.LICENSE.txt",
        sha256="34dee5fd5e5cc756efb5ad4d64652bce719bdf5e900ca5d7538253e737930bc4",
        sources=["https://github.com/FormidableLabs/victory/blob/dd86278d205f3f306e2ab38c317a6f9c56f0a6f8/LICENSE.txt (tag v36.9.2)"],
        tarball=["package/lib-vendor/*/LICENSE"],
        note="victory-vendor re-publishes d3 modules; their own licences are read from the "
             "verified npm tarball's lib-vendor/*/LICENSE.",
    ),
}

# Licence family as recognised from the text of a licence file, mapped to the
# SPDX ids that family is consistent with. Used only to FLAG disagreements
# for a human; the declared licence is always printed as-is.
FAMILIES = [
    ("Apache", re.compile(r"Apache License", re.I), {"Apache-2.0"}),
    ("MIT", re.compile(r"Permission is hereby granted, free of charge", re.I), {"MIT", "MIT-0"}),
    ("ISC", re.compile(r"Permission to use, copy, modify, and(/or)? distribute this software", re.I), {"ISC", "0BSD"}),
    ("BSD", re.compile(r"Redistribution and use in source and binary forms", re.I), {"BSD-2-Clause", "BSD-3-Clause"}),
    ("CC-BY", re.compile(r"Attribution 4\.0 International", re.I), {"CC-BY-4.0"}),
    ("CC0", re.compile(r"CC0 1\.0 Universal|Creative Commons Legal Code\s+CC0", re.I), {"CC0-1.0"}),
    ("Unlicense", re.compile(r"This is free and unencumbered software", re.I), {"Unlicense"}),
]


# The canonical SPDX id for a family recognised in a licence text, used only
# by --inventory for a package the lockfile declares no licence for. BSD has
# no entry: the text alone does not say 2- or 3-clause, so --inventory fails
# on such a package rather than guess.
FAMILY_SPDX = {"Apache": "Apache-2.0", "MIT": "MIT", "ISC": "ISC", "CC-BY": "CC-BY-4.0",
               "CC0": "CC0-1.0", "Unlicense": "Unlicense"}


def spdx_tokens(expr: str) -> set[str]:
    return {t for t in re.split(r"[()\s]+", expr or "") if t and t not in ("AND", "OR", "WITH")}


def fetch(url: str, dest: str) -> bytes:
    if not url.startswith(REGISTRY):
        raise SystemExit(f"refusing non-registry URL: {url}")
    if os.path.exists(dest):
        with open(dest, "rb") as f:
            return f.read()
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
    with open(dest, "wb") as f:
        f.write(data)
    return data


def verify(data: bytes, integrity: str, what: str) -> None:
    algo, _, want = integrity.partition("-")
    if algo != "sha512":
        raise SystemExit(f"{what}: integrity is {algo}, not sha512")
    have = base64.b64encode(hashlib.sha512(data).digest()).decode()
    if have != want:
        raise SystemExit(f"{what}: sha512 MISMATCH (lockfile {want}, tarball {have})")


def read_package(data: bytes) -> tuple[list[tuple[str, str]], str | None]:
    """(licence files at the package root as (name, text), package.json license)."""
    files: list[tuple[str, str]] = []
    pj_license = None
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf:
        for m in tf.getmembers():
            if not m.isfile():
                continue
            parts = m.name.split("/")
            if len(parts) != 2:  # only the package root (`package/…` or similar)
                continue
            base = parts[1]
            if base == "package.json":
                try:
                    pj = json.loads(tf.extractfile(m).read().decode("utf-8", "replace"))
                    lic = pj.get("license")
                    if isinstance(lic, dict):
                        lic = lic.get("type")
                    if lic is None and isinstance(pj.get("licenses"), list):
                        lic = " OR ".join(str(x.get("type", x)) if isinstance(x, dict) else str(x) for x in pj["licenses"])
                    pj_license = lic if isinstance(lic, str) else None
                except ValueError:
                    pass
            elif LICENSE_FILE.match(base):
                text = tf.extractfile(m).read().decode("utf-8", "replace")
                files.append((base, text.replace("\r\n", "\n").rstrip() + "\n"))
    files.sort()
    return files, pj_license


def read_tarball_files(data: bytes, patterns: list[str]) -> list[tuple[str, str]]:
    """Licence files matching fnmatch `patterns` anywhere in a verified tarball."""
    found: list[tuple[str, str]] = []
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf:
        for m in tf.getmembers():
            if m.isfile() and any(fnmatch.fnmatchcase(m.name, pat) for pat in patterns):
                text = tf.extractfile(m).read().decode("utf-8", "replace")
                found.append((m.name.split("/", 1)[-1], text.replace("\r\n", "\n").rstrip() + "\n"))
    return sorted(found)


def curated_texts(name: str, ver: str, data: bytes) -> tuple[list[tuple[str, str]], list[str]]:
    """(licence texts, notes) for a CURATED package; SystemExit on any mismatch."""
    c = CURATED[(name, ver)]
    if "external" in c:
        return [], [f"not bundled: {c['external']}"]
    path = os.path.join(CURATED_DIR, c["text"])
    with open(path, "rb") as f:
        raw = f.read()
    have = hashlib.sha256(raw).hexdigest()
    if have != c["sha256"]:
        raise SystemExit(f"{name}@{ver}: curated {c['text']} sha256 {have}, table pins {c['sha256']}")
    text = raw.decode("utf-8").replace("\r\n", "\n").rstrip() + "\n"
    notes = ["npm tarball ships no licence file; licence text curated (sources below)"]
    if c.get("note"):
        notes.append(c["note"])
    notes += [f"Source: {src}" for src in c["sources"]]
    notes.append(f"Curated text: proofwidgets-js-licences/{c['text']} (sha256 {c['sha256']})")
    texts = [(f"{c['text']} (curated)", text)]
    if c.get("tarball"):
        extra = read_tarball_files(data, c["tarball"])
        if not extra:
            raise SystemExit(f"{name}@{ver}: curated tarball patterns {c['tarball']} matched nothing")
        texts += extra
    return texts, notes


def tarball_for(name: str, ver: str, v: dict, dl_dir: str) -> bytes:
    url, integ = v.get("resolved"), v.get("integrity")
    if not url or not integ:
        raise SystemExit(f"{name}@{ver}: lockfile has no resolved/integrity")
    dest = os.path.join(dl_dir, re.sub(r"[^A-Za-z0-9._-]", "_", f"{name}-{ver}.tgz"))
    data = fetch(url, dest)
    verify(data, integ, f"{name}@{ver}")
    return data


def inventory(lock_path: str, pw_commit: str, dl_dir: str) -> int:
    with open(lock_path, "rb") as f:
        lock_bytes = f.read()
    h = hashlib.sha256(lock_bytes).hexdigest()
    lock = json.loads(lock_bytes)
    os.makedirs(dl_dir, exist_ok=True)
    rows = []
    undeclared = []  # (name, resolved licence) for the header note
    unknown = []  # no licence from the lockfile, package.json or a LICENSE family
    for k, v in lock["packages"].items():
        if not k or v.get("dev"):
            continue
        name, ver = k.split("node_modules/")[-1], v.get("version", "?")
        lic = v.get("license")
        if not lic:
            files, pj_lic = read_package(tarball_for(name, ver, v, dl_dir))
            fam = None
            for _fname, text in files:
                for fname_fam, rx, _ids in FAMILIES:
                    if rx.search(text):
                        fam = FAMILY_SPDX.get(fname_fam)
                        break
                if fam:
                    break
            if pj_lic:
                lic = f"{pj_lic} (undeclared in package-lock.json; package.json in the npm tarball)"
                undeclared.append((name, pj_lic, "package.json"))
            elif fam:
                lic = f"{fam} (undeclared in package-lock.json; LICENSE file in the npm tarball)"
                undeclared.append((name, fam, "LICENSE"))
            else:
                unknown.append(f"{name}@{ver}")
                continue
        rows.append((name, ver, lic))
    if unknown:
        for u in unknown:
            print(f"ERROR {u}: no licence in package-lock.json or package.json, and its npm tarball's "
                  "licence files match no family in FAMILY_SPDX. Read the tarball and declare it.",
                  file=sys.stderr)
        raise SystemExit(f"{len(unknown)} package(s) with no resolvable licence; nothing written")
    rows.sort()
    declared = sorted({r[2] for r in rows if "(undeclared" not in r[2]})
    note = "".join(
        f" ({n} declares none in the lockfile; its npm tarball's {src} is {l})" for n, l, src in sorted(undeclared)
    )
    out = sys.stdout
    out.write(f"""Third-party npm packages in ProofWidgets4 {pw_commit[:7]}'s widget JavaScript
=====================================================================

ProofWidgets commits its infoview JavaScript prebuilt (widget/js/*.js,
bundled by rollup from npm and minified by terser), and its .olean files
embed those strings via `include_str`. The minified bundles carry almost
no licence notices. This inventory is every non-dev package in the
committed widget/package-lock.json, with the licence that lockfile
declares. It is a SUPERSET of what the bundles contain: react, react-dom
and @leanprover/infoview are rollup externals (supplied by the editor at
runtime, not bundled), and other packages may be tree-shaken away.

Licences declared: {", ".join(declared)}{note}

package-lock.json sha256: {h}
(the package build fails if the pinned ProofWidgets lockfile differs;
regenerate this file from the new lockfile when ProofWidgets is bumped.)

""")
    w = max(len(r[0]) for r in rows)
    for n, ver, l in rows:
        out.write(f"{n.ljust(w)}  {ver:<12}  {l}\n")
    return 0


def main() -> int:
    if sys.argv[1:2] == ["--inventory"]:
        return inventory(*sys.argv[2:5])
    lock_path, pw_commit, dl_dir = sys.argv[1:4]
    with open(lock_path, "rb") as f:
        lock_bytes = f.read()
    lock_sha = hashlib.sha256(lock_bytes).hexdigest()
    lock = json.loads(lock_bytes)
    os.makedirs(dl_dir, exist_ok=True)

    pkgs: dict[tuple[str, str], dict] = {}
    for path, v in lock["packages"].items():
        if not path or v.get("dev"):
            continue
        name = path.split("node_modules/")[-1]
        key = (name, v["version"])
        if key not in pkgs:
            pkgs[key] = v

    entries = []
    flags = []
    missing = []  # licence-less packages with no CURATED entry
    used = set()
    for (name, ver) in sorted(pkgs):
        v = pkgs[(name, ver)]
        data = tarball_for(name, ver, v, dl_dir)
        files, pj_lic = read_package(data)
        lock_lic = v.get("license")
        declared = lock_lic or pj_lic or "NOASSERTION"
        notes = []
        if lock_lic and pj_lic and lock_lic != pj_lic:
            notes.append(f"lockfile says {lock_lic!r} but package.json says {pj_lic!r}")
        if not lock_lic:
            notes.append(f"lockfile declares no licence; package.json says {pj_lic!r}")
        toks = spdx_tokens(declared)
        for fname, text in files:
            for fam, rx, ids in FAMILIES:
                if rx.search(text) and not (ids & toks):
                    notes.append(f"{fname} reads as {fam} but the declared licence is {declared!r}")
                    break
        how = None
        if not files:
            if (name, ver) in CURATED:
                used.add((name, ver))
                files, cnotes = curated_texts(name, ver, data)
                notes += cnotes
                how = "not bundled (rollup external)" if not files else "curated upstream text"
            else:
                missing.append(f"{name}@{ver} (declared {declared})")
        if any("reads as" in n or "but package.json" in n for n in notes):
            flags.append(f"{name}@{ver}: " + "; ".join(notes))
        entries.append((name, ver, declared, files, notes, how))

    stale = sorted(f"{n}@{v}" for (n, v) in CURATED if (n, v) not in used)
    if missing or stale:
        for m in missing:
            print(f"ERROR {m}: npm tarball ships no licence file and CURATED has no entry. "
                  "Find the upstream licence text at the matching tag and add it.", file=sys.stderr)
        for m in stale:
            print(f"ERROR {m}: CURATED entry matches no licence-less package in this lockfile; "
                  "drop or update it.", file=sys.stderr)
        raise SystemExit(f"{len(missing)} package(s) without licence text, {len(stale)} stale CURATED entr(ies); "
                         "nothing written")

    out = sys.stdout
    out.write("Third-party notices: npm code in ProofWidgets4's prebuilt widget JavaScript\n")
    out.write("=" * 76 + "\n\n")
    out.write(
        "ProofWidgets4 commits its infoview JavaScript prebuilt (widget/js/*.js,\n"
        "bundled by rollup from npm and minified by terser), and its .olean files\n"
        "embed it via `include_str`, so the `mathlib` package redistributes it. The\n"
        "minified bundles strip most copyright notices; they are reproduced here.\n\n"
        "Generated by packages/mathlib/gen-proofwidgets-notice.py from the exact\n"
        "npm tarballs the lockfile resolves (each verified against its sha512\n"
        "`integrity`), covering every non-dev package in the lockfile. That is a\n"
        "superset of what the bundles contain (react, react-dom and\n"
        "@leanprover/infoview are rollup externals; others may be tree-shaken).\n"
        "Licence texts are verbatim from each tarball's root LICENSE / LICENCE /\n"
        "COPYING / NOTICE files. Where a tarball ships none, the text is curated\n"
        "from upstream at the matching release (sources and sha256 in the entry;\n"
        "the generator refuses to run while any such package lacks one).\n\n"
    )
    out.write(f"ProofWidgets4 commit: {pw_commit}\n")
    out.write(f"package-lock.json sha256: {lock_sha}\n")
    out.write(f"packages: {len(entries)}\n")
    nofile = [(f"{n}@{v}", how) for n, v, _, _, _, how in entries if how]
    out.write(f"packages whose npm tarball ships no licence file: {len(nofile)}"
              " (each resolved below, from curated upstream text or as not bundled)\n")
    for x, how in nofile:
        out.write(f"  - {x}: {how}\n")
    out.write(f"packages flagged for review: {len(flags)}\n")
    for fl in flags:
        out.write(f"  - {fl}\n")
    out.write("\n")
    for name, ver, declared, files, notes, _how in entries:
        out.write("-" * 76 + "\n")
        out.write(f"{name}@{ver}\nLicense: {declared}\n")
        for n in notes:
            out.write(f"Note: {n}\n")
        for fname, text in files:
            out.write(f"\n--- {fname} ---\n{text}")
        out.write("\n")
    print(f"{len(entries)} packages, {len(flags)} flagged", file=sys.stderr)
    for fl in flags:
        print("FLAG " + fl, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
