#!/usr/bin/env python3
"""Generate ui-THIRD-PARTY-NOTICES for llama.cpp's embedded web UI (pkgs#994).

llama-server embeds the llama-ui dist bundle pinned in build.ncl. The bundle is
minified and carries none of the license texts or NOTICE files of the npm
packages compiled into it. This script rebuilds that list from the llama.cpp
source at the pinned version and writes one deterministic notices file, which
build.sh installs to usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES.

The build does NOT run this script. Rerun it on every llama.cpp bump: build.sh
fails closed when the header's UI version, lock sha256 or dist sha256 no longer
match what is being built.

Usage (from the pkgs repo root; V is the `version` in build.ncl, e.g. b12640):

    W=$(mktemp -d)
    gcloud storage cat --project=minimal-pkgsec \
      gs://minimal-staging-archives/ggml-org/llama.cpp/$V.tar.gz > $W/src.tar.gz
    gcloud storage cat --project=minimal-pkgsec \
      gs://minimal-staging-archives/ggml-org/llama-ui/$V-dist.tar.gz > $W/dist.tar.gz
    python3 -I packages/llama.cpp/gen-ui-notices.py \
      --src $W/src.tar.gz --dist $W/dist.tar.gz --cache $W/npm \
      --out packages/llama.cpp/ui-THIRD-PARTY-NOTICES

Both tarballs are checked against the sha256 pins in build.ncl. Needs network
access to registry.npmjs.org and an authenticated `gh` (for llama-brand, which
the lock resolves from GitHub rather than npm). Nothing downloaded is executed
or installed: each npm tarball is checked against the lock's `integrity` and
only its top-level LICENSE*/LICENCE*/COPYING*/NOTICE* files and package.json
are read.

Where the UI lives. Between b12359 and b12640 it moved to ui/: the app (Llama
Chat) in ui/apps/chat, and two libraries it compiles from source rather than
installing, Llama UI (ui/lib/ui, its src/lib) and Llama Voice (ui/lib/voice,
its src). The app's vite config resolves every bare import of those library
sources from the APP's node_modules (ui/apps/chat/scripts/llama-ui.js), so
ui/apps/chat/package-lock.json is the one lock that says what is bundled; the
libraries' own locks are for their standalone dev builds and are not read.
Before that the app was tools/ui; this script handles only the ui/ layout.

Which packages count as bundled. The app lists every dependency, runtime or
not, under devDependencies (the SvelteKit convention: the app is bundled, never
installed), so the lock's `dev` flag says nothing. Instead the roots are the
bare specifiers that the app's src, Llama UI's src/lib and Llama Voice's src
import for their value (`import type`, *.d.ts, tests and stories are skipped;
CSS @import/@plugin/@use count; the workspace's own @ggml-org/llama-ui and
@ggml-org/llama-voice, which vite aliases to those sources, are not packages),
plus the workbox modules the dist's service worker reports
(`workbox:<module>:`), if it is a workbox one.
From the roots the closure follows dependencies, optionalDependencies and
installed peerDependencies, resolved the way node resolves the lock's
node_modules tree. It does not enter @types/* (declarations only) or the build
tools in STOP below, which are only peers. The closure is conservative: it
keeps e.g. the MCP SDK's server-side dependencies, which the client bundle may
tree-shake away. Listing too much is harmless here; listing too little is not.
"""

import argparse
import base64
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import tarfile
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
USER_AGENT = "gominimal-pkgmgr-agent"

# Build tools reached only as peerDependencies (of @sveltejs/kit, svelte's esrap,
# ...). They shape the bundle but none of their code is in it.
STOP = {"vite", "typescript", "@sveltejs/vite-plugin-svelte", "sass", "@typescript-eslint/types"}
# Native Node addons, which a browser bundle cannot contain: pdfjs-dist's optional
# @napi-rs/canvas (loaded only when pdf.js runs under Node). Lock entries with an
# `os` or `cpu` constraint (its per-platform binaries) are skipped as well.
NODE_ONLY = {"@napi-rs/canvas"}

# The SPDX id comes from package.json's `license`; these packages have none, so
# it is taken from the LICENSE in the repository named. The generator stops on
# any other package without one: check its repository, then add it here.
# A package whose npm tarball has no license file gets the standard text of its
# SPDX id (STANDARD_TEXTS), with a copyright line naming package.json's
# `author`, and is listed in the header.
NO_SPDX = {
    "khroma": ("MIT", "https://github.com/fabiospampinato/khroma"),
    "runed": ("MIT", "https://github.com/svecosystem/runed"),
    "svelte-toolbelt": ("MIT", "https://github.com/huntabyte/svelte-toolbelt"),
}

MIT_TEXT = """MIT License

{copyright}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""
STANDARD_TEXTS = {"MIT": MIT_TEXT}

# License files a package keeps below its top level, which npm_files would miss.
# llama-brand (from npm since the ui/ move, from GitHub before): its top-level
# LICENSE is CC-BY-NC-4.0 for the logos, the grant that lets us redistribute
# them is BRAND-USAGE.md, the CSS is MIT (css/LICENSE) and the fonts OFL-1.1
# (fonts/OFL.txt). The generator stops if one of them is missing.
EXTRA_LICENSE_FILES = {
    "@ggml-org/llama-brand": ("BRAND-USAGE.md", "css/LICENSE", "fonts/OFL.txt"),
}

# Fonts in Llama UI's sources (not an npm package) that the dist embeds, with
# the license file beside them: ui/<FONTS_DIR>, and the woff2 names the dist
# must carry (hashed: _app/immutable/assets/LlamaSans.<hash>.woff2).
FONTS_DIR = "lib/ui/src/lib/assets/fonts/"
FONTS = ("LlamaSans", "LlamaMono")

LICENSE_FILE = re.compile(r"^(LICEN[CS]E|COPYING|NOTICE)([.\-_].*)?$", re.I)
NOTICE_FILE = re.compile(r"^NOTICE([.\-_].*)?$", re.I)
SRC_EXT = (".ts", ".js", ".svelte", ".css", ".scss")
SKIP_SRC = re.compile(r"\.(spec|test|stories)\.|\.d\.ts$")
IMPORT_RE = re.compile(
    r"""\b(import|export)\s+(type\s+)?(?:[\w*{}\s,$]*?\bfrom\s*)?['"]([^'"\n]+)['"]"""
    r"""|\bimport\s*\(\s*['"]([^'"\n]+)['"]"""
    r"""|@(?:import|plugin|use)\s+['"]([^'"\n]+)['"]"""
)
WORKBOX_RE = re.compile(rb"workbox:([a-z-]+):")
# Paths under ui/ in the llama.cpp source.
APP = "apps/chat/"
SRC_TREES = (APP + "src/", "lib/ui/src/lib/", "lib/voice/src/")
VENDORS = APP + "src/lib/vendors/"
# The workspace's own libraries, compiled from SRC_TREES (vite aliases).
WORKSPACE = {"@ggml-org/llama-ui", "@ggml-org/llama-voice"}
# Bare-specifier aliases in ui/apps/chat/vite.config.ts, to the package they name.
ALIASES = {"katex-fonts": "katex"}
SEP = "=" * 79
SUB = "-" * 79


def die(msg):
    sys.exit("gen-ui-notices: " + msg)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def text(data):
    s = data.decode("utf-8", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
    return "\n".join(line.rstrip() for line in s.strip("\n").split("\n")) + "\n"


def read_pins():
    ncl = open(os.path.join(HERE, "build.ncl"), encoding="utf-8").read()
    m = re.search(r'let version = "([^"]+)"', ncl)
    if not m:
        die("no `let version` in build.ncl")
    pins = {}
    for key, marker in (("src", "ggml-org/llama.cpp/%{version}.tar.gz"),
                        ("dist", "ggml-org/llama-ui/%{version}-dist.tar.gz")):
        i = ncl.find(marker)
        h = re.search(r'sha256 = "([0-9a-f]{64})"', ncl[i:]) if i >= 0 else None
        if not h:
            die("no sha256 pin after " + marker + " in build.ncl")
        pins[key] = h.group(1)
    return m.group(1), pins


def package_name(spec):
    spec = spec.split("?", 1)[0]
    parts = spec.split("/")
    return "/".join(parts[:2]) if spec.startswith("@") else parts[0]


def scan_roots(src_files):
    """Bare specifiers the bundled sources (SRC_TREES) import for their value."""
    value, typed = set(), set()
    for path, data in src_files.items():
        # The app's src/lib/vendors is listed separately; its imports are aliased to itself.
        if SKIP_SRC.search(path) or not path.endswith(SRC_EXT) or path.startswith(VENDORS):
            continue
        for m in IMPORT_RE.finditer(data.decode("utf-8", errors="replace")):
            spec = m.group(3) or m.group(4) or m.group(5)
            # `#lib/...` is a package.json `imports` alias into the same tree.
            if not spec or spec[0] in "./$~#" or spec.startswith(("virtual:", "\0")) or ":" in spec:
                continue
            name = package_name(spec)
            if name in WORKSPACE:
                continue
            # vite.config.ts aliases katex-fonts to node_modules/katex/dist/fonts.
            name = ALIASES.get(name, name)
            (typed if m.group(2) else value).add(name)
    return value


def load_src(path, version):
    prefix = "llama.cpp-%s/ui/" % version
    lock = pkg = None
    src, vendors = {}, {}
    seen_trees = set()
    with tarfile.open(path, "r:gz") as tf:
        for m in tf:
            if not m.isfile() or not m.name.startswith(prefix):
                continue
            rel = m.name[len(prefix):]
            if rel == APP + "package-lock.json":
                lock = tf.extractfile(m).read()
            elif rel == APP + "package.json":
                pkg = tf.extractfile(m).read()
            elif rel.startswith(SRC_TREES):
                tree = next(t for t in SRC_TREES if rel.startswith(t))
                seen_trees.add(tree)
                data = tf.extractfile(m).read()
                src[rel] = data
                if rel == FONTS_DIR + "OFL.txt":
                    vendors.setdefault(FONTS_DIR, {})["OFL.txt"] = data
                if rel.startswith(VENDORS):
                    parts = rel[len(VENDORS):].split("/")
                    if len(parts) == 2 and LICENSE_FILE.match(parts[1]):
                        vendors.setdefault(parts[0], {})[parts[1]] = data
    if lock is None or pkg is None:
        die("ui/%spackage-lock.json or package.json missing from the source tarball" % APP)
    for tree in SRC_TREES:
        if tree not in seen_trees:
            die("ui/%s is missing from the source tarball: has the UI layout changed?" % tree)
    return lock, json.loads(pkg), src, vendors


def load_dist(path):
    version, workbox, fonts = None, set(), set()
    with tarfile.open(path, "r:gz") as tf:
        for m in tf:
            if not m.isfile():
                continue
            name = m.name[2:] if m.name.startswith("./") else m.name
            base = name.rsplit("/", 1)[-1]
            if base.endswith(".woff2"):
                fonts.add(base.split(".", 1)[0])
            if name == "build.json":
                version = json.loads(tf.extractfile(m).read()).get("version")
            elif name.endswith(".js"):
                workbox |= {w.decode() for w in WORKBOX_RE.findall(tf.extractfile(m).read())}
    return version, {"workbox-" + w for w in workbox}, fonts


def closure(lock, roots):
    P = lock["packages"]

    def resolve(frm, name):
        base = frm
        while True:
            k = (base + "/" if base else "") + "node_modules/" + name
            if k in P:
                return k
            if not base:
                return None
            i = base.rfind("/node_modules/")
            base = base[:i] if i >= 0 else ""

    seen, stack = set(), []
    for r in sorted(roots):
        k = resolve("", r)
        if not k:
            die("root %r is not in package-lock.json" % r)
        stack.append(k)
    while stack:
        k = stack.pop()
        if k in seen:
            continue
        seen.add(k)
        v = P[k]
        deps = {}
        for field in ("dependencies", "optionalDependencies", "peerDependencies"):
            deps.update(v.get(field, {}))
        for d in deps:
            if d in STOP or d in NODE_ONLY or d.startswith("@types/"):
                continue
            r = resolve(k, d)
            if r and ("os" in P[r] or "cpu" in P[r]):
                continue
            if r:
                stack.append(r)
            elif d in v.get("dependencies", {}):
                die("%s needs %s, which the lock does not resolve" % (k, d))
    out = {}
    for k in seen:
        name = k.rsplit("node_modules/", 1)[1]
        out.setdefault((name, P[k]["version"]), P[k])
    return out


def fetch(url, cache):
    os.makedirs(cache, exist_ok=True)
    dest = os.path.join(cache, hashlib.sha256(url.encode()).hexdigest() + ".tgz")
    if not os.path.exists(dest):
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        with open(dest + ".part", "wb") as f:
            f.write(data)
        os.replace(dest + ".part", dest)
        time.sleep(0.2)
    return open(dest, "rb").read()


def check_integrity(data, integrity, what):
    best = None
    for item in integrity.split():
        algo, _, b64 = item.partition("-")
        if algo in ("sha512", "sha384", "sha256") and (best is None or algo > best[0]):
            best = (algo, b64)
    if best is None:
        die("%s: no sha256/384/512 integrity in the lock (%s)" % (what, integrity))
    got = base64.b64encode(hashlib.new(best[0], data).digest()).decode()
    if got != best[1]:
        die("%s: %s mismatch (lock %s, got %s)" % (what, best[0], best[1], got))
    return best[0]


def npm_files(data, extra=()):
    files, pkg = {}, None
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf:
        for m in tf:
            parts = m.name.split("/")
            if m.isfile() and "/".join(parts[1:]) in extra:
                files["/".join(parts[1:])] = tf.extractfile(m).read()
                continue
            if len(parts) != 2 or not m.isfile():
                continue
            if parts[1] == "package.json":
                pkg = json.loads(tf.extractfile(m).read())
            elif LICENSE_FILE.match(parts[1]):
                files[parts[1]] = tf.extractfile(m).read()
    if pkg is None:
        die("tarball has no top-level package.json")
    return files, pkg


def spdx_of(pkg):
    lic = pkg.get("license")
    if isinstance(lic, dict):
        lic = lic.get("type")
    if not lic and isinstance(pkg.get("licenses"), list):
        lic = " OR ".join(x.get("type", "") for x in pkg["licenses"] if isinstance(x, dict))
    lic = (lic or "").strip()
    if lic.startswith("(") and lic.endswith(")"):
        lic = lic[1:-1]
    return lic


def git_files(owner_repo, commit, paths, cache):
    """Files at a pinned commit, through git (which checks every object's hash)."""
    repo = os.path.join(cache, "git-" + owner_repo.replace("/", "-"))
    git = ["git", "-c", "core.hooksPath=/dev/null", "-C", repo]
    if not os.path.isdir(repo):
        subprocess.run(["git", "init", "-q", "--bare", repo], check=True)
    if subprocess.run(git + ["cat-file", "-e", commit + "^{commit}"], capture_output=True).returncode:
        subprocess.run(git + ["fetch", "-q", "--depth", "1", "https://github.com/%s" % owner_repo, commit],
                       check=True)
    return {p: subprocess.run(git + ["show", "%s:%s" % (commit, p)], check=True,
                              capture_output=True).stdout for p in paths}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--src", required=True, help="llama.cpp source tarball (the pinned Source)")
    ap.add_argument("--dist", required=True, help="llama-ui dist.tar.gz (the pinned Source)")
    ap.add_argument("--cache", required=True, help="download cache directory")
    ap.add_argument("--out", required=True, help="notices file to write")
    a = ap.parse_args()

    version, pins = read_pins()
    src_bytes, dist_bytes = open(a.src, "rb").read(), open(a.dist, "rb").read()
    for key, data in (("src", src_bytes), ("dist", dist_bytes)):
        if sha256(data) != pins[key]:
            die("--%s sha256 %s != build.ncl pin %s" % (key, sha256(data), pins[key]))

    lock_bytes, ui_pkg, src_files, vendors = load_src(a.src, version)
    dist_version, workbox, dist_fonts = load_dist(a.dist)
    if dist_version != version:
        die("dist build.json version %r != build.ncl version %r" % (dist_version, version))
    lock = json.loads(lock_bytes)

    roots = scan_roots(src_files) | workbox
    pkgs = closure(lock, roots)

    sections, no_file, by_license = [], [], {}
    for (name, ver), entry in sorted(pkgs.items()):
        url = entry.get("resolved", "")
        what = "%s@%s" % (name, ver)
        if url.startswith("https://registry.npmjs.org/"):
            data = fetch(url, a.cache)
            algo = check_integrity(data, entry.get("integrity", ""), what)
            extra = EXTRA_LICENSE_FILES.get(name, ())
            files, pkg = npm_files(data, extra)
            for f in extra:
                if f not in files:
                    die("%s: %s is not in the npm tarball" % (what, f))
            spdx = spdx_of(pkg) or entry.get("license") or ""
            source = "%s (%s verified against package-lock.json)" % (url, algo)
        elif url.startswith("https://codeload.github.com/"):
            # llama-brand: the lock pins a GitHub commit archive, whose integrity
            # GitHub's archives don't reproduce byte for byte. Read the files at
            # that commit with git instead; the commit hash pins them.
            m = re.match(r"https://codeload\.github\.com/([^/]+/[^/]+)/tar\.gz/([0-9a-f]{40})$", url)
            if not m:
                die("%s: unrecognised resolved URL %s" % (what, url))
            files = git_files(m.group(1), m.group(2), ["package.json", "LICENSE", "BRAND-USAGE.md"], a.cache)
            pkg = json.loads(files.pop("package.json"))
            spdx = spdx_of(pkg)
            source = "https://github.com/%s at commit %s (read with git)" % m.groups()
        else:
            die("%s: unsupported resolved URL %r" % (what, url))

        notes = []
        ref = "its package.json"
        if not spdx and name in NO_SPDX:
            spdx, ref = NO_SPDX[name]
            ref = "the LICENSE in " + ref
            notes.append("package.json has no `license`; %s per %s" % (spdx, ref))
        if not spdx:
            die("%s has no `license` in package.json; check its repo, add it to NO_SPDX" % what)
        if not any(not NOTICE_FILE.match(f) for f in files):
            author = pkg.get("author")
            if isinstance(author, dict):
                author = author.get("name")
            # "Name <email> (url)" -> "Name"
            author = re.sub(r"\s*(<[^>]*>|\([^)]*\))", "", author or "").strip()
            copyright_line = ("Copyright (c) %s" % author) if author else ("Copyright (c) the %s authors" % name)
            if spdx not in STANDARD_TEXTS:
                die("%s: no standard text for %s" % (what, spdx))
            files["(standard %s text; no license file in the npm tarball)" % spdx] = \
                STANDARD_TEXTS[spdx].format(copyright=copyright_line).encode()
            notes.append("No license file in the npm tarball; %s per %s" % (spdx, ref))
            no_file.append(what)
        if not any(NOTICE_FILE.match(f) for f in files):
            notes.append("NOTICE: none in the package")
        by_license[spdx] = by_license.get(spdx, 0) + 1
        sections.append((name, ver, spdx, source, notes, files))

    # Code vendored into ui/apps/chat/src (bundled through the nerdamer vite plugin),
    # not in the lock. Their license files sit beside the source.
    vendor_sections = []
    font_files = vendors.pop(FONTS_DIR, None)
    if font_files is None:
        die("ui/%sOFL.txt is missing from the source tarball" % FONTS_DIR)
    if not set(FONTS) <= dist_fonts:
        die("the dist has no %s woff2: check what fonts it embeds" % ", ".join(sorted(set(FONTS) - dist_fonts)))
    # (KaTeX's fonts are inlined in its CSS as data: URLs, not woff2 files, and
    # are covered by katex's own MIT section.)
    if dist_fonts - set(FONTS):
        die("the dist embeds fonts this script does not account for: %s"
            % ", ".join(sorted(dist_fonts - set(FONTS))))
    vendor_sections.append(("Llama Sans and Llama Mono (fonts)", "vendored", "OFL-1.1",
                            "llama.cpp %s ui/%s (the dist's %s woff2)" % (version, FONTS_DIR, ", ".join(FONTS)),
                            ["NOTICE: none in the package"], font_files))
    by_license["OFL-1.1"] = by_license.get("OFL-1.1", 0) + 1
    vendor_spdx = {"big-integer": "Unlicense", "decimal.js": "MIT", "nerdamer-prime": "MIT"}
    for vname in sorted(vendors):
        if vname not in vendor_spdx:
            die("vendored %s: add its SPDX id to vendor_spdx" % vname)
        vendor_sections.append((vname, "vendored", vendor_spdx[vname],
                                "llama.cpp %s ui/%s%s" % (version, VENDORS, vname),
                                ["NOTICE: none in the package"], vendors[vname]))
        by_license[vendor_spdx[vname]] = by_license.get(vendor_spdx[vname], 0) + 1
    for vname in vendor_spdx:
        if vname not in vendors:
            die("vendored %s has no license file in ui/%s" % (vname, VENDORS))

    out = []
    w = out.append
    w("Third-party notices for llama-server's embedded web UI (llama-ui)")
    w("")
    w("llama-ui version: %s" % version)
    w("llama-ui dist sha256: %s" % pins["dist"])
    w("package-lock sha256: %s" % sha256(lock_bytes))
    w("llama.cpp source sha256: %s" % pins["src"])
    w("")
    w("Generated by packages/llama.cpp/gen-ui-notices.py from ui/apps/chat/package-lock.json")
    w("in the llama.cpp %s source; do not edit by hand. build.sh checks the UI" % version)
    w("version, dist sha256 and lock sha256 above against what it builds.")
    w("")
    w("The bundle compiles in %d npm packages (name@version, from the lock), %d"
      % (len(sections), len(vendor_sections) - 1))
    w("libraries vendored in ui/apps/chat/src/lib/vendors and Llama UI's fonts")
    w("(ui/%s). Licenses:" % FONTS_DIR)
    for lic, n in sorted(by_license.items(), key=lambda x: (-x[1], x[0])):
        w("  %-40s %d" % (lic, n))
    w("")
    w("No license file in the npm tarball, so the standard text of the package's")
    w("SPDX id is given, with its package.json author as the copyright holder:")
    for what in no_file or ["none"]:
        w("  " + what)
    w("")
    w("@ggml-org/llama-brand: its logos, favicons and app icons are CC-BY-NC-4.0")
    w("(its LICENSE), its CSS MIT (css/LICENSE) and its fonts OFL-1.1")
    w("(fonts/OFL.txt). The marks are declared as LicenseRef-llama-brand:")
    w("CC-BY-NC-4.0 plus the grant in its BRAND-USAGE.md (reproduced below), which")
    w("permits redistribution, including commercially, as part of software")
    w("distributions and packages.")
    for name, ver, spdx, source, notes, files in sections + vendor_sections:
        w("")
        w(SEP)
        w("%s@%s" % (name, ver))
        w("License: %s" % spdx)
        w("Source: %s" % source)
        for n in notes:
            w(n)
        for fname in sorted(files, key=lambda f: (bool(NOTICE_FILE.match(f)), f)):
            w(SUB)
            w("[%s]" % fname)
            w("")
            out.append(text(files[fname]).rstrip("\n"))
    body = "\n".join(out) + "\n"
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(body)
    print("wrote %s: %d npm packages, %d vendored, %d bytes; no license file: %s"
          % (a.out, len(sections), len(vendor_sections), len(body.encode()), ", ".join(no_file) or "none"),
          file=sys.stderr)


if __name__ == "__main__":
    main()
