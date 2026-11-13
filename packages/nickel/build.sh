#!/bin/sh
set -ex

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# >>> pkgmgr lock-patch (generated; regenerate with `pkgmgr lock-patch nickel`, never edit)
# security-floors-lock.patch is a cargo-resolved delta against upstream's Cargo.lock; it is
# only valid for the exact lock it was generated from.
echo "2fdafec3df7887a526b84bb95bb5ae43c25ecbd48a3da73e89d232dd0dcb3ec2  Cargo.lock" | sha256sum -c --status - || {
  echo "ERROR: upstream Cargo.lock changed; run: pkgmgr lock-patch nickel" >&2
  exit 1
}
patch -Np1 -i ./security-floors-lock.patch
# Security floors (version-agnostic): no locked version below a fixed release.
if grep -A1 '^name = "anyhow"$' Cargo.lock | grep -qE '^version = "1[.]0[.](([0-9]|[1-9][0-9]|10[0-2])([-+][^"]*)?|103-[^"]*)"$'; then
  echo "ERROR: anyhow below its security floor 1.0.103 is in Cargo.lock (RUSTSEC-2026-0190)" >&2
  exit 1
fi
if grep -A1 '^name = "crossbeam-epoch"$' Cargo.lock | grep -qE '^version = "0[.]9[.](([0-9]|1[0-9])([-+][^"]*)?|20-[^"]*)"$'; then
  echo "ERROR: crossbeam-epoch below its security floor 0.9.20 is in Cargo.lock (RUSTSEC-2026-0204)" >&2
  exit 1
fi
if grep -A1 '^name = "cxx"$' Cargo.lock | grep -qE '^version = "1[.]0[.](([0-9]|[1-9][0-9]|1[0-8][0-9]|19[0-4])([-+][^"]*)?|195-[^"]*)"$'; then
  echo "ERROR: cxx below its security floor 1.0.195 is in Cargo.lock (RUSTSEC-2026-0202)" >&2
  exit 1
fi
if grep -A1 '^name = "faster-hex"$' Cargo.lock | grep -qE '^version = "0[.]10[.]((0)([-+][^"]*)?|1-[^"]*)"$'; then
  echo "ERROR: faster-hex below its security floor 0.10.1 is in Cargo.lock (RUSTSEC-2026-0306)" >&2
  exit 1
fi
if grep -A1 '^name = "h2"$' Cargo.lock | grep -qE '^version = "0[.]4[.](([0-9]|1[0-5])([-+][^"]*)?|16-[^"]*)"$'; then
  echo "ERROR: h2 below its security floor 0.4.16 is in Cargo.lock (RUSTSEC-2026-0258)" >&2
  exit 1
fi
if grep -A1 '^name = "memmap2"$' Cargo.lock | grep -qE '^version = "0[.]9[.](([0-9]|10)([-+][^"]*)?|11-[^"]*)"$'; then
  echo "ERROR: memmap2 below its security floor 0.9.11 is in Cargo.lock (RUSTSEC-2026-0186)" >&2
  exit 1
fi
if grep -A1 '^name = "quinn-proto"$' Cargo.lock | grep -qE '^version = "0[.]11[.](([0-9]|1[0-7])([-+][^"]*)?|18-[^"]*)"$'; then
  echo "ERROR: quinn-proto below its security floor 0.11.18 is in Cargo.lock (RUSTSEC-2026-0338, RUSTSEC-2026-0339, RUSTSEC-2026-0340, RUSTSEC-2026-0341, RUSTSEC-2026-0342)" >&2
  exit 1
fi
if grep -A1 '^name = "rustls"$' Cargo.lock | grep -qE '^version = "0[.]23[.](([0-9]|[1-3][0-9]|4[0-5])([-+][^"]*)?|46-[^"]*)"$'; then
  echo "ERROR: rustls below its security floor 0.23.46 is in Cargo.lock (RUSTSEC-2026-0285, RUSTSEC-2026-0346, RUSTSEC-2026-0348, RUSTSEC-2026-0349)" >&2
  exit 1
fi
if grep -A1 '^name = "rustls-webpki"$' Cargo.lock | grep -qE '^version = "0[.]103[.](([0-9]|1[0-5])([-+][^"]*)?|16-[^"]*)"$'; then
  echo "ERROR: rustls-webpki below its security floor 0.103.16 is in Cargo.lock (RUSTSEC-2026-0382)" >&2
  exit 1
fi
if grep -A1 '^name = "tokio"$' Cargo.lock | grep -qE '^version = "(1[.]51[.](([0-5])([-+][^"]*)?|6-[^"]*)|1[.]47[.][0-9]+([-+][^"]*)?)"$'; then
  echo "ERROR: tokio below its security floor 1.51.6 is in Cargo.lock (RUSTSEC-2026-0386)" >&2
  exit 1
fi
if grep -A1 '^name = "webpki-root-certs"$' Cargo.lock | grep -qE '^version = "1[.]0[.](([0-9])([-+][^"]*)?|10-[^"]*)"$'; then
  echo "ERROR: webpki-root-certs below its security floor 1.0.10 is in Cargo.lock (RUSTSEC-2026-0383)" >&2
  exit 1
fi
# <<< pkgmgr lock-patch

# Security floor (data/security_floors.toml): kept by pkgmgr when the lock
# patch it guarded became unnecessary. No pre-fix version may be locked.
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

cargo build --locked --release -p nickel-lang-cli

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/nickel $OUTPUT_DIR/usr/bin/
