#!/bin/sh
# Imported from Wolfi `tealdeer` (1.8.1, rust) by pkgmgr import-wolfi.
set -eu
export CC=gcc
export LD=gcc
# Reproducibility (per minimal-repro's guide): strip absolute build
# paths (source dir + cargo registry) and disable incremental builds.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0
# Security floor, CVE-2026-111943 (eMudhra CA distrust): Cargo.lock must not
# lock rustls-webpki < 0.103.16 or webpki-roots / webpki-root-certs < 1.0.10,
# the releases that drop the distrusted roots. Upstream's lock meets this, so
# no lock patch is carried. (The standalone test in build.ncl runs only when
# this file changes: tests are not part of the spec hash.)
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

# TLS roots: build ONLY the rustls-with-native-roots backend, so tldr trusts
# the system CA store (/etc/ssl/certs) instead of the webpki-roots list
# compiled into the binary, and a fix to ca-certificates reaches it without a
# rebuild (CVE-2026-111943, eMudhra). Upstream's default features compile both
# rustls backends and its config default is the first compiled one, which is
# webpki. Dropping the webpki backend is what makes native roots the default;
# a config naming `rustls-with-webpki-roots` now fails with "Unsupported TLS
# backend" rather than silently trusting the compiled-in list.
cargo build --locked --release --no-default-features --features rustls-with-native-roots
mkdir -p "$OUTPUT_DIR/usr/bin"
cp "target/release/tldr" "$OUTPUT_DIR/usr/bin/"
