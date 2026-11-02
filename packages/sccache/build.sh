#!/bin/sh
# Imported from Wolfi `sccache` (0.16.0, rust) by pkgmgr import-wolfi.
set -eu
export CC=gcc
export LD=gcc
# Reproducibility (per minimal-repro's guide): strip absolute build
# paths (source dir + cargo registry) and disable incremental builds.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0
# CVE-2026-111943: move upstream's Cargo.lock to rustls-webpki 0.103.16 and
# webpki-roots / webpki-root-certs 1.0.10 (see build.ncl). Applied by name so a
# missing or stale patch fails the build.
patch -Np1 -i ./cve-2026-111943-webpki-lock.patch
# Prove it landed, fail-closed: the fixed verifier is locked, and no pre-fix
# rustls-webpki 0.103.x or webpki-roots / webpki-root-certs 1.0.x remains.
grep -A1 '^name = "rustls-webpki"$' Cargo.lock | grep -q '^version = "0.103.16"$' || {
  echo "ERROR: rustls-webpki 0.103.16 is not in Cargo.lock (CVE-2026-111943)" >&2
  exit 1
}
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9]|0[.]26[.]([0-9]|10))"$'; then
  # 0.26.0-0.26.10 webpki-roots carry their own (pre-distrust) root list;
  # 0.26.11 is the shim that re-exports webpki-roots 1.x.
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

# OpenSSL 4: openssl-sys 0.9.117 and openssl 0.10.81 (see build.ncl). Fail closed if the bump
# did not land.
patch -Np1 -i ./openssl-4-openssl-sys-lock.patch
grep -A1 '^name = "openssl-sys"$' Cargo.lock | grep -q '^version = "0.9.117"$' || {
  echo "ERROR: openssl-sys 0.9.117 is not in Cargo.lock (OpenSSL 4)" >&2
  exit 1
}

cargo build --locked --release
mkdir -p "$OUTPUT_DIR/usr/bin"
cp "target/release/sccache" "$OUTPUT_DIR/usr/bin/"
