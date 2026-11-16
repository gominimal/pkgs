#!/usr/bin/env python3
"""bootstrap-pin guard: every gs://minimal-bootstrap pin names an object its generation published.

A package that starts from a bootstrap generation pins one object:

    url = "gs://minimal-bootstrap/gen-16/sha256/<sha256>/<name>-<arch>.tar.zst",
    sha256 = "<sha256>",

Sources are fetched by sha256, so a pin whose url and sha256 disagree, or whose
url names an object the generation never published, still evaluates and still
passes every check that does not download it. It fails later, in whichever
build first misses the store. The generation's own MANIFEST.txt (one
`<sha256>  sha256/<sha256>/<file>` line per object, published beside the
objects and readable anonymously) is the record of what exists.

Rules, each an error:

  1. shape     The url is not gs://minimal-bootstrap/gen-<N>/sha256/<64 hex>/<file>.
  2. sha256    The sha256 in the url path is not the Source's sha256.
  3. manifest  gen-<N>/MANIFEST.txt has no line for that sha256 and file.
  4. arch      The file is another architecture's object: it ends -x86_64 in
               the arm64 catalog or -aarch64 in the amd64 one.

Two inputs, because each sees what the other cannot. The evaluated catalog
(`mip dump -p --format json --arch <arch>`) gives the url after Nickel
interpolation, paired with its sha256, on the architecture that uses it; rules
1 to 4 run there. The text of packages/ and stacks/ is scanned as well, for
url literals no package on either architecture evaluates; rules 1 and 3 run
there.

Exit codes: 0 = PASS, 1 = a bad pin, 2 = UNVERIFIED (a dump, a scanned
directory or a published generation's MANIFEST.txt could not be read, or an
input yielded no pin at all). 2 is deliberately non-zero: a guard that cannot
see the catalog or the manifest must not report success. A pin naming a
generation that has no MANIFEST.txt (HTTP 404: a typo, or a generation not
released yet) is a bad pin, rule 3, reported at the pin; only a read that
fails for another reason is UNVERIFIED.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

BUCKET = "gs://minimal-bootstrap/"
PIN = re.compile(r"^gs://minimal-bootstrap/(gen-[0-9]+)/sha256/([0-9a-f]{64})/([^/]+)$")
LITERAL = re.compile(r"gs://minimal-bootstrap/[^\"'\s]*")
MANIFEST_URL = "https://storage.googleapis.com/minimal-bootstrap/{gen}/MANIFEST.txt"
OTHER_ARCH = {"amd64": "-aarch64", "arm64": "-x86_64"}
SCANNED = (".ncl", ".sh", ".toml", ".json", ".kaem")


class Unverified(Exception):
    pass


class Unpublished(Exception):
    """The generation has no MANIFEST.txt: the pin is wrong, not the guard."""


def parse_manifest(text: str) -> set[tuple[str, str]]:
    """(sha256, file) for every `<sha256>  sha256/<sha256>/<file>` line."""
    out = set()
    for line in text.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        sha, path = parts
        bits = path.split("/")
        if len(bits) == 3 and bits[0] == "sha256" and bits[1] == sha:
            out.add((sha, bits[2]))
    return out


class Manifests:
    """gen-N -> its published objects, read once each from a directory or the bucket."""

    def __init__(self, directory: str | None = None):
        self.directory = directory
        self.cache: dict[str, set[tuple[str, str]]] = {}

    def read(self, gen: str) -> str:
        if self.directory:
            try:
                with open(os.path.join(self.directory, f"{gen}.txt"), encoding="utf-8") as f:
                    return f.read()
            except FileNotFoundError as e:
                raise Unpublished(gen) from e
        try:
            with urllib.request.urlopen(MANIFEST_URL.format(gen=gen), timeout=60) as r:
                return r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                raise Unpublished(gen) from e
            raise

    def objects(self, gen: str) -> set[tuple[str, str]] | None:
        """The generation's objects, or None when it has no MANIFEST.txt."""
        if gen not in self.cache:
            try:
                found = parse_manifest(self.read(gen))
            except Unpublished:
                self.cache[gen] = None
                return None
            except (OSError, urllib.error.URLError, UnicodeDecodeError) as e:
                raise Unverified(f"{gen}/MANIFEST.txt: {e}") from e
            if not found:
                raise Unverified(f"{gen}/MANIFEST.txt lists no objects")
            self.cache[gen] = found
        return self.cache[gen]

    def published(self) -> list[str]:
        return sorted((g for g, o in self.cache.items() if o is not None), key=lambda g: int(g[4:]))


def check_url(url: str, manifests: Manifests) -> list[str]:
    """Rules 1 and 3."""
    m = PIN.match(url)
    if not m:
        return [f"shape: {url} is not gs://minimal-bootstrap/gen-<N>/sha256/<sha256>/<file>"]
    gen, sha, name = m.groups()
    objects = manifests.objects(gen)
    if objects is None:
        return [f"manifest: {gen} is not published (no {gen}/MANIFEST.txt); "
                "check the generation number, or wait for its release"]
    if (sha, name) not in objects:
        return [f"manifest: {gen}/MANIFEST.txt does not list {sha} as {name}"]
    return []


def check_pin(url: str, sha256: str | None, arch: str | None, manifests: Manifests) -> list[str]:
    """Rules 1 to 4 for one evaluated Source."""
    problems = check_url(url, manifests)
    m = PIN.match(url)
    if not m:
        return problems
    _, sha, name = m.groups()
    if (sha256 or "").lower() != sha:
        problems.append(f"sha256: url names {sha} but the Source's sha256 is {sha256}")
    stem = name.split(".tar", 1)[0]
    if arch in OTHER_ARCH and stem.endswith(OTHER_ARCH[arch]):
        problems.append(f"arch: {name} is pinned in the {arch} catalog")
    return problems


def pins(node) -> list[tuple[str, str | None]]:
    """(url, sibling sha256) of every bootstrap url anywhere in an evaluated package."""
    out = []
    if isinstance(node, dict):
        url = node.get("url")
        if isinstance(url, str) and url.startswith(BUCKET):
            sha = node.get("sha256")
            out.append((url, sha if isinstance(sha, str) else None))
        for v in node.values():
            out.extend(pins(v))
    elif isinstance(node, list):
        for v in node:
            out.extend(pins(v))
    return out


def load(path: str) -> list[dict]:
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        raise Unverified(f"{path}: {e}") from e
    if isinstance(data, dict):  # tolerate a {name: spec} shape
        data = [dict(v, name=k) for k, v in data.items()]
    if not isinstance(data, list) or not data:
        raise Unverified(f"{path}: expected a non-empty list of packages")
    return data


def check_dump(path: str, arch: str, manifests: Manifests) -> tuple[int, list[str]]:
    """(pins seen, failures) for one architecture's dump."""
    seen, failures = 0, []
    for pkg in sorted(load(path), key=lambda p: p.get("name") or ""):
        for url, sha in sorted(set(pins(pkg)), key=lambda p: p[0]):
            seen += 1
            for problem in check_pin(url, sha, arch, manifests):
                failures.append(f"{arch} {pkg.get('name')}: {problem}")
    return seen, failures


def walk_error(e: OSError) -> None:
    # os.walk skips a directory it cannot list unless told otherwise, and a
    # missing root yields nothing at all; either would pass unseen pins.
    raise Unverified(f"{e.filename}: {e.strerror or e}")


def check_tree(roots: list[str], manifests: Manifests) -> tuple[int, list[str]]:
    """(literals seen, failures) over the text of every scanned file under roots."""
    seen, failures = 0, []
    for root in roots:
        for dirpath, dirnames, filenames in os.walk(root, onerror=walk_error):
            dirnames.sort()
            for fn in sorted(filenames):
                if not fn.endswith(SCANNED):
                    continue
                path = os.path.join(dirpath, fn)
                try:
                    with open(path, encoding="utf-8", errors="replace") as f:
                        lines = f.read().splitlines()
                except OSError as e:
                    raise Unverified(f"{path}: {e}") from e
                for n, line in enumerate(lines, 1):
                    for url in LITERAL.findall(line):
                        if "%{" in url:  # interpolated: the dump sees the result
                            continue
                        seen += 1
                        for problem in check_url(url, manifests):
                            failures.append(f"{path}:{n}: {problem}")
    return seen, failures


def run(dumps: list[tuple[str, str]], trees: list[str], manifest_dir: str | None) -> int:
    manifests = Manifests(manifest_dir)
    failures, empty = [], []
    try:
        for arch, path in dumps:
            n, bad = check_dump(path, arch, manifests)
            print(f"checked {n} pins in {os.path.basename(path)} ({arch})")
            failures += bad
            if not n:
                empty.append(f"{path} ({arch})")
        if trees:
            n, bad = check_tree(trees, manifests)
            print(f"checked {n} url literals under {', '.join(trees)}")
            failures += bad
            if not n:
                empty.append(", ".join(trees))
    except Unverified as e:
        print(f"UNVERIFIED {e}")
        return 2
    for f in failures:
        print(f"::error title=bootstrap-pin-guard::{f}" if os.environ.get("GITHUB_ACTIONS") else f"FAIL {f}")
    if failures:
        print(f"{len(failures)} bad pin(s). Copy url and sha256 from the generation's manifest "
              "(gominimal/bootstrap generations/gen-N/manifest.json, or tools/pkgs-flip.py).")
        return 1
    # Each input on its own: the tree scan always finds literals, so a total
    # would let a dump that lost its pins (a dump format that drops
    # replace_on_cycle, a changed Source shape) pass with rules 2 and 4 unrun.
    if empty:
        for e in empty:
            print(f"UNVERIFIED no gs://minimal-bootstrap pin found in {e}; the catalog has some, so the input is wrong")
        return 2
    print(f"PASS ({', '.join(manifests.published())})")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dump", nargs=2, action="append", default=[], metavar=("ARCH", "JSON"),
                    help="mip dump -p --format json --arch ARCH output; repeat per arch")
    ap.add_argument("--tree", action="append", default=[], metavar="DIR",
                    help="directory whose files are scanned for url literals; repeatable")
    ap.add_argument("--manifest-dir", metavar="DIR",
                    help="read gen-N.txt from DIR instead of the bucket")
    a = ap.parse_args()
    if not a.dump and not a.tree:
        ap.error("give --dump and/or --tree")
    return run([(arch, path) for arch, path in a.dump], a.tree, a.manifest_dir)


if __name__ == "__main__":
    sys.exit(main())
