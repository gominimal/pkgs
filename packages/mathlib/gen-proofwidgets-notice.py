#!/usr/bin/env python3
"""Generate proofwidgets-js-NOTICE.txt: third-party notices for the npm code
bundled into ProofWidgets' prebuilt widget JavaScript.

Why: ProofWidgets commits its infoview JS prebuilt (widget/js/*.js, rollup +
terser), and its .olean files embed it via `include_str`, so the `mathlib`
package redistributes that code. The minified bundles strip almost every
copyright notice that MIT / ISC / BSD require to travel with the code. This
script rebuilds those notices from the exact npm tarballs the pinned
package-lock.json resolves.

Run it on a maintainer host (NOT in the build) whenever ProofWidgets is
bumped, then commit the output beside build.ncl:

    python3 -I gen-proofwidgets-notice.py \\
        <ProofWidgets4 checkout>/widget/package-lock.json \\
        <ProofWidgets commit sha> \\
        <fresh empty download dir> \\
        > proofwidgets-js-NOTICE.txt

build.sh refuses to package if the lockfile sha256 recorded in the output
differs from the pinned ProofWidgets lockfile, so a stale file cannot ship.

Safety: the tarballs are untrusted DATA. Nothing from them is executed or
written to disk except the tarball itself; licence files and package.json are
read out of the archive in memory. Each tarball is verified against the
lockfile's `integrity` (sha512) before it is read. Only registry.npmjs.org
URLs are fetched. Python stdlib only.
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

USER_AGENT = "gominimal-pkgmgr-agent (+https://github.com/gominimal)"
REGISTRY = "https://registry.npmjs.org/"
LICENSE_FILE = re.compile(r"^(LICEN[CS]E|COPYING|NOTICE)([._-].*)?$", re.I)

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


def main() -> int:
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
    for (name, ver) in sorted(pkgs):
        v = pkgs[(name, ver)]
        url, integ = v.get("resolved"), v.get("integrity")
        if not url or not integ:
            raise SystemExit(f"{name}@{ver}: lockfile has no resolved/integrity")
        dest = os.path.join(dl_dir, re.sub(r"[^A-Za-z0-9._-]", "_", f"{name}-{ver}.tgz"))
        data = fetch(url, dest)
        verify(data, integ, f"{name}@{ver}")
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
        if not files:
            notes.append("no licence file shipped upstream in the npm tarball")
        if any("reads as" in n or "but package.json" in n for n in notes):
            flags.append(f"{name}@{ver}: " + "; ".join(notes))
        entries.append((name, ver, declared, files, notes))

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
        "COPYING / NOTICE files.\n\n"
    )
    out.write(f"ProofWidgets4 commit: {pw_commit}\n")
    out.write(f"package-lock.json sha256: {lock_sha}\n")
    out.write(f"packages: {len(entries)}\n")
    nofile = [f"{n}@{v}" for n, v, _, files, _ in entries if not files]
    out.write(f"packages whose npm tarball ships no licence file: {len(nofile)}"
              " (upstream publishes no licence text for these; their declared SPDX licence is recorded)\n")
    for x in nofile:
        out.write(f"  - {x}\n")
    out.write(f"packages flagged for review: {len(flags)}\n")
    for fl in flags:
        out.write(f"  - {fl}\n")
    out.write("\n")
    for name, ver, declared, files, notes in entries:
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
