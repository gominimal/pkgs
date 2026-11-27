#!/bin/sh
# Imported from Wolfi `sccache` (0.16.0, rust) by pkgmgr import-wolfi.
set -eu
export CC=gcc
export LD=gcc
# Reproducibility (per minimal-repro's guide): strip absolute build
# paths (source dir + cargo registry) and disable incremental builds.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0
# Security floor, CVE-2026-111943 (eMudhra CA distrust): Cargo.lock must not
# lock rustls-webpki < 0.103.16, webpki-roots / webpki-root-certs 1.0.0-1.0.9,
# or a webpki-roots 0.26 before the 0.26.11 shim. Upstream's 0.20.0 lock meets
# this (rustls-webpki 0.103.16), so no lock patch is carried.
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9]|0[.]26[.]([0-9]|10))"$'; then
  # 0.26.0-0.26.10 webpki-roots carry their own (pre-distrust) root list;
  # 0.26.11 is the shim that re-exports webpki-roots 1.x.
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

# OpenSSL 4: openssl-sys before 0.9.114 panics in its build script on OpenSSL 4.x.
# Upstream's 0.20.0 lock carries 0.9.118, so no lock patch is needed; fail closed
# if a release ever ships an older one.
osys=$(grep -A1 '^name = "openssl-sys"$' Cargo.lock | sed -n 's/^version = "\(.*\)"$/\1/p')
case "$osys" in
  0.9.*) [ "${osys#0.9.}" -ge 114 ] 2>/dev/null ;;
  0.[1-9][0-9].* | [1-9]*.*) true ;;
  *) false ;;
esac || {
  echo "ERROR: Cargo.lock's openssl-sys ($osys) predates 0.9.114 and fails on OpenSSL 4" >&2
  exit 1
}

cargo build --locked --release
mkdir -p "$OUTPUT_DIR/usr/bin"
cp "target/release/sccache" "$OUTPUT_DIR/usr/bin/"
