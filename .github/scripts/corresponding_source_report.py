#!/usr/bin/env python3
"""Report-only corresponding-source check (gominimal/inbox#283, #53).

For every COPYLEFT package (classified from its license_spdx expression), verify
that the exact source archive it is built from is durably available on the
public mirror (gs://minimal-staging-archives). Distributing a copyleft binary
from the cache carries a corresponding-source obligation; the mirror is our
mechanism for meeting it — so a copyleft package whose source is unmirrored
(fetched straight from GitHub/upstream) or whose mirror object has gone missing
is a compliance gap. Exactness rides on the build's own sha256 pin: if the
mirrored object drifted, builds would already fail, so presence == exactness.

Categories per copyleft package:
  ✅ mirrored     — every source URL is the mirror and the object exists
  ❌ mirror-miss  — a mirror URL whose object is GONE (drift/GC: the worst case)
  ✅ mirrored-oob — fetches upstream directly, but the archive IS present on
                    the mirror at the conventional path (mirrored out-of-band;
                    repoint the URL at the next natural version bump)
  ⚠️ unmirrored   — fetches upstream directly AND the mirror holds no copy; a
                    mirroring action is needed for the offer to hold
  ❓ unresolved   — URL interpolation couldn't be resolved statically

Presence is probed with unauthenticated HTTPS HEADs against the public bucket
(https://storage.googleapis.com/minimal-staging-archives/<path>) — no gcloud,
no secrets. Only that fixed host is ever contacted, and only with
charset-validated paths taken from tracked build.ncl (no SSRF surface).

REPORT-ONLY: exits 0 for any policy verdict; non-zero only on a programming
error (downgraded to a warning by the workflow). MUST NOT be a required check.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

_LICENSE_RE = re.compile(r'^\s*(?:attrs\.)?license_spdx\s*=\s*"([^"]*)"', re.M)
_URL_RE = re.compile(r'^\s*url\s*=\s*"([^"]+)"', re.M)
_LET_RE = re.compile(r'^\s*let\s+([A-Za-z_][A-Za-z0-9_-]*)\s*=\s*"([^"]*)"\s+in\s*$', re.M)
_INTERP_RE = re.compile(r"%\{([A-Za-z_][A-Za-z0-9_-]*)\}")
_MIRROR = "gs://minimal-staging-archives/"
_MIRROR_HTTP = "https://storage.googleapis.com/minimal-staging-archives/"
_SAFE_PATH = re.compile(r"^[A-Za-z0-9_./+~-]+$")

# SPDX id prefixes that carry source obligations on binary distribution.
# Strong and weak/file-level copyleft both create a corresponding-source duty
# for the covered code, so both are in scope. Prefix-matched against expression
# tokens (GPL-2.0-only, LGPL-2.1-or-later, AGPL-3.0-only, MPL-2.0, ...).
_COPYLEFT_PREFIXES = (
    "GPL-", "AGPL-", "LGPL-", "SSPL-", "MPL-", "EPL-", "CDDL-", "EUPL-",
    "CeCILL", "OSL-", "MS-RL", "CPL-", "IPL-", "RPL-", "CC-BY-SA-",
)
_TOKEN_SPLIT = re.compile(r"[()\s]+")


def copyleft_tokens(expr: str) -> list[str]:
    toks = [t for t in _TOKEN_SPLIT.split(expr) if t and t not in ("AND", "OR", "WITH")]
    return [t for t in toks if t.startswith(_COPYLEFT_PREFIXES)]


def resolve_interpolations(url: str, lets: dict[str, str]) -> str:
    # let-bindings can reference each other (dl_base uses %{version}); a few
    # passes of textual substitution resolves the practical cases.
    for _ in range(5):
        expanded = _INTERP_RE.sub(lambda m: lets.get(m.group(1), m.group(0)), url)
        if expanded == url:
            break
        url = expanded
    return url


def conventional_dest(url: str) -> str:
    """Where the mirror convention would place this upstream URL: GitHub ->
    <owner>/<repo>/<basename>, other hosts -> flat <basename> (matches the
    existing 289 mirrored sources and the inbox#283 backfill)."""
    m = re.match(r"https://github\.com/([^/]+)/([^/]+)/", url)
    base = url.split("?")[0].rstrip("/").split("/")[-1]
    return f"{m.group(1)}/{m.group(2)}/{base}" if m else base


def head_mirror_object(path: str) -> bool | None:
    """True/False = object present/absent on the public mirror; None = probe
    failed (network/5xx) — reported as unknown rather than missing."""
    if not _SAFE_PATH.match(path):
        return None
    try:
        p = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
             "--head", "--proto", "=https", "--max-time", "20",
             _MIRROR_HTTP + path],
            capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        return None
    code = p.stdout.strip()
    if code == "200":
        return True
    if code in ("403", "404"):  # public bucket: absent objects read as 403/404
        return False
    return None


def md_cell(s) -> str:
    return (str(s).replace("\\", "\\\\").replace("|", "\\|")
            .replace("`", "\\`").replace("\r", " ").replace("\n", " "))


def emit(markdown: str) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a") as f:
            f.write(markdown)
    else:
        print("\n" + markdown)


def main() -> int:
    ap = argparse.ArgumentParser()
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--all", action="store_true")
    grp.add_argument("--packages-file")
    args = ap.parse_args()

    if args.all:
        try:
            names = sorted(d for d in os.listdir("packages")
                           if os.path.isfile(os.path.join("packages", d, "build.ncl")))
        except OSError:
            names = []
    else:
        try:
            with open(args.packages_file) as f:
                names = [ln.strip() for ln in f if ln.strip()]
        except OSError as e:
            emit("## corresponding-source report (informational, non-blocking)\n\n"
                 f"> Could not read packages file ({type(e).__name__}); skipping.\n")
            return 0

    rows = []
    counts = {"mirrored": 0, "mirrored-oob": 0, "mirror-miss": 0, "unmirrored": 0, "unresolved": 0, "probe-unknown": 0}
    for name in names:
        try:
            with open(os.path.join("packages", name, "build.ncl"), encoding="utf-8") as f:
                src = f.read()
        except OSError:
            continue
        m = _LICENSE_RE.search(src)
        if not m:
            continue
        cl = copyleft_tokens(m.group(1))
        if not cl:
            continue

        lets = dict(_LET_RE.findall(src))
        urls = [resolve_interpolations(u, lets) for u in _URL_RE.findall(src)]
        # Local `file =` deps and empty specs: a copyleft package with no URLs
        # builds from in-repo sources; the repo itself is the source offer.
        verdicts, details = [], []
        for u in urls:
            if "%{" in u:
                verdicts.append("unresolved")
                details.append(f"unresolved interpolation: {u}")
            elif u.startswith(_MIRROR):
                # minimal's gs:// fetcher tolerates doubled slashes (graphviz's
                # build.ncl has a literal `//` and builds fine) — normalize so
                # the probe matches fetcher behavior instead of phantom-missing.
                path = re.sub(r"/{2,}", "/", u[len(_MIRROR):].lstrip("/"))
                present = head_mirror_object(path)
                if present is True:
                    verdicts.append("mirrored")
                elif present is False:
                    verdicts.append("mirror-miss")
                    details.append(f"MISSING from mirror: {u}")
                else:
                    verdicts.append("probe-unknown")
                    details.append(f"probe failed: {u}")
            elif u.startswith("https://"):
                dest = conventional_dest(u)
                present = head_mirror_object(dest)
                if present is True:
                    verdicts.append("mirrored-oob")
                    details.append(f"mirror holds {dest}; build.ncl still fetches upstream")
                elif present is False:
                    verdicts.append("unmirrored")
                    details.append(f"upstream-only: {u}")
                else:
                    verdicts.append("probe-unknown")
                    details.append(f"probe failed: {dest}")
            else:
                verdicts.append("unmirrored")
                details.append(f"upstream-only: {u}")

        if not urls:
            continue  # nothing fetched -> nothing to mirror
        # Package verdict = worst URL verdict.
        order = ["mirror-miss", "unmirrored", "unresolved", "probe-unknown", "mirrored-oob", "mirrored"]
        worst = min(verdicts, key=order.index)
        counts[worst] += 1
        icon = {"mirrored": "✅", "mirrored-oob": "✅", "mirror-miss": "❌",
                "unmirrored": "⚠️", "unresolved": "❓", "probe-unknown": "❓"}[worst]
        licenses = " ".join(sorted(set(cl)))
        rows.append((name, licenses, f"{icon} {worst}", "; ".join(details) or "—"))
        print(f"{name} [{licenses}] -> {worst}" + (f" ({'; '.join(details)})" if details else ""))

    sev = ["mirror-miss", "unmirrored", "unresolved", "probe-unknown", "mirrored-oob", "mirrored"]
    rows.sort(key=lambda r: (sev.index(r[2].split()[1]), r[0]))

    out = [
        "## corresponding-source report (informational, non-blocking)", "",
        "For every **copyleft** package (GPL/LGPL/AGPL/MPL/…, classified from "
        "`license_spdx`), is the exact source archive it is built from durably "
        "available on the public mirror? Distribution of a copyleft binary from "
        "the cache carries a corresponding-source obligation (gominimal/inbox#283 "
        "/ #53); the mirror is the offer. Exactness rides on the build's sha256 "
        "pin — presence is what can drift.", "",
        f"**{counts['mirrored'] + counts['mirrored-oob']} mirrored ✅ "
        f"(of which {counts['mirrored-oob']} out-of-band) · "
        f"{counts['mirror-miss']} mirror-MISSING ❌ · "
        f"{counts['unmirrored']} unmirrored ⚠️ · "
        f"{counts['unresolved'] + counts['probe-unknown']} unresolved/unknown ❓**", "",
    ]
    flagged = [r for r in rows if r[2].split()[1] not in ("mirrored", "mirrored-oob")] or rows[:0]
    shown = rows if not args.all else (flagged if flagged else [])
    if shown:
        out += ["| package | copyleft license(s) | verdict | detail |",
                "| --- | --- | --- | --- |"]
        out += ["| " + " | ".join(md_cell(c) for c in r) + " |" for r in shown]
    elif args.all:
        out.append("✅ Every copyleft package's source is mirrored and present.")
    out += ["",
            "> Report-only; never blocks and is excluded from required checks. "
            "⚠️ unmirrored = fetched straight from upstream — the mirror holds "
            "no copy, so the source offer depends on a third party. ❌ = a "
            "mirror object we point at is gone (the drift this check exists to "
            "catch)."]
    emit("\n".join(out) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
