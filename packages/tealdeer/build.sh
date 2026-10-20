#!/bin/sh
# Imported from Wolfi `tealdeer` (1.8.1, rust) by pkgmgr import-wolfi.
set -eu
export CC=gcc
export LD=gcc
# Reproducibility (per minimal-repro's guide): strip absolute build
# paths (source dir + cargo registry) and disable incremental builds.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0
# TLS roots: build ONLY the rustls-with-native-roots backend, so tldr trusts
# the system CA store (/etc/ssl/certs) instead of the webpki-roots list
# compiled into the binary, and a fix to ca-certificates reaches it without a
# rebuild (CVE-2026-111943, eMudhra). Upstream's default features compile both
# rustls backends and its config default is the first compiled one, which is
# webpki. Dropping the webpki backend is what makes native roots the default;
# a config naming `rustls-with-webpki-roots` now fails with "Unsupported TLS
# backend" rather than silently trusting the compiled-in list.
cargo build --release --no-default-features --features rustls-with-native-roots
mkdir -p "$OUTPUT_DIR/usr/bin"
cp "target/release/tldr" "$OUTPUT_DIR/usr/bin/"
