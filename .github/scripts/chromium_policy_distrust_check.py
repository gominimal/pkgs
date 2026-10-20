#!/usr/bin/env python3
"""Keep Chromium's distrust policy aligned with the canonical denylist.

packages/ca-certificates/distrust.txt is the tree's one list of distrusted
certificates and keys (`<cert|spki> <64 lowercase hex>  <note>`). Chromium's
`CADistrustedCertificates` policy (packages/chromium-policies/
ca-distrusted-certificates.json) needs whole base64 DER certificates, so it
cannot be generated from those hashes. This check makes sure the two never
drift: every certificate in the policy must have its SubjectPublicKeyInfo
SHA-256 listed as an `spki` line in distrust.txt.

The reverse is not required. distrust.txt also lists roots and issuers that
the Chrome Root Store never trusted (e.g. Sectigo AAA, emSign Root TLS CA - G3),
which the policy has no reason to repeat.

Exit codes: 0 aligned (or distrust.txt not on this branch yet, which is
reported as a warning), 1 drift or a malformed input, 2 the built-in negative
control failed (the check itself is broken).

Pure standard library: the SPKI is cut out of the DER by a minimal parser,
so the result does not depend on the runner's openssl.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import re
import sys

POLICY = "packages/chromium-policies/ca-distrusted-certificates.json"
DENYLIST = "packages/ca-certificates/distrust.txt"
_LINE_RE = re.compile(r"^(cert|spki) ([0-9a-f]{64})(?:\s+(.*))?$")


def _tlv(buf: bytes, pos: int) -> tuple[int, int, int]:
    """Return (tag, content_start, content_end) of the DER TLV at `pos`."""
    if pos + 2 > len(buf):
        raise ValueError("truncated DER")
    tag = buf[pos]
    length = buf[pos + 1]
    pos += 2
    if length & 0x80:
        n = length & 0x7F
        if n == 0 or n > 4 or pos + n > len(buf):
            raise ValueError("bad DER length")
        length = int.from_bytes(buf[pos : pos + n], "big")
        pos += n
    if pos + length > len(buf):
        raise ValueError("DER length past end of buffer")
    return tag, pos, pos + length


def spki_sha256(der: bytes) -> str:
    """SHA-256 of the DER SubjectPublicKeyInfo of an X.509 certificate."""
    tag, start, end = _tlv(der, 0)
    if tag != 0x30 or end != len(der):
        raise ValueError("not a DER certificate")
    tag, pos, tbs_end = _tlv(der, start)  # tbsCertificate
    if tag != 0x30:
        raise ValueError("no tbsCertificate")
    tag, _, nxt = _tlv(der, pos)
    if tag == 0xA0:  # [0] EXPLICIT version
        pos = nxt
    # serialNumber, signature, issuer, validity, subject
    for want in (0x02, 0x30, 0x30, 0x30, 0x30):
        tag, _, nxt = _tlv(der, pos)
        if tag != want:
            raise ValueError("unexpected tbsCertificate layout")
        pos = nxt
    tag, _, spki_end = _tlv(der, pos)
    if tag != 0x30 or spki_end > tbs_end:
        raise ValueError("no subjectPublicKeyInfo")
    return hashlib.sha256(der[pos:spki_end]).hexdigest()


def load_denylist_spkis(path: str) -> set[str]:
    spkis: set[str] = set()
    with open(path, encoding="utf-8") as f:
        for n, raw in enumerate(f, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            m = _LINE_RE.match(line)
            if not m:
                raise ValueError(f"{path}:{n}: malformed line: {line!r}")
            if m.group(1) == "spki":
                spkis.add(m.group(2))
    return spkis


def load_policy_spkis(path: str) -> list[str]:
    with open(path, encoding="utf-8") as f:
        doc = json.load(f)
    certs = doc.get("CADistrustedCertificates") if isinstance(doc, dict) else None
    if not isinstance(certs, list) or not certs:
        raise ValueError(f"{path}: no CADistrustedCertificates list")
    return [spki_sha256(base64.b64decode(c, validate=True)) for c in certs]


def missing(policy_spkis: list[str], deny: set[str]) -> list[str]:
    return [s for s in policy_spkis if s not in deny]


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    policy_path = os.path.join(root, POLICY)
    deny_path = os.path.join(root, DENYLIST)

    try:
        policy_spkis = load_policy_spkis(policy_path)
    except (OSError, ValueError) as e:
        print(f"::error::{e}")
        return 1
    print(f"{POLICY}: {len(policy_spkis)} certificates")

    if not os.path.exists(deny_path):
        print(
            f"::warning::{DENYLIST} is not on this branch yet (it arrives with "
            "gominimal/pkgs#948); the policy/denylist alignment check activates "
            "once it lands."
        )
        return 0

    try:
        deny = load_denylist_spkis(deny_path)
    except (OSError, ValueError) as e:
        print(f"::error::{e}")
        return 1
    print(f"{DENYLIST}: {len(deny)} spki entries")

    # Negative control: drop the denylist entry for the first policy key and
    # require the check to notice. A check that cannot fail proves nothing.
    if not missing(policy_spkis, deny - {policy_spkis[0]}):
        print("::error::negative control passed; the alignment check is broken")
        return 2

    gaps = missing(policy_spkis, deny)
    if gaps:
        for s in gaps:
            print(
                f"::error file={POLICY}::policy certificate with SPKI {s} has no "
                f"`spki {s}` line in {DENYLIST}"
            )
        return 1
    print(f"OK: all {len(policy_spkis)} policy keys are `spki` entries in {DENYLIST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
