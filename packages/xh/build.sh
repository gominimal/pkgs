#!/bin/sh
# Imported from Wolfi `xh` (0.26.1, rust) by pkgmgr import-wolfi.
set -eu
export CC=gcc
export LD=gcc
# Reproducibility (per minimal-repro's guide): strip absolute build
# paths (source dir + cargo registry) and disable incremental builds.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0
# CVE-2026-111943 regression guard, fail-closed. Upstream's Cargo.lock has carried
# the fixed crates since 0.26.3 (rustls-webpki 0.103.16 distrusts the 8 eMudhra
# intermediates; webpki-root-certs 1.0.10 drops emSign ECC Root CA - G3), so the
# carried lock patch is gone. Keep proving it on every bump: the verifier must be
# present, and no pre-fix rustls-webpki 0.103.x or webpki-roots / webpki-root-certs
# 1.0.x may come back.
grep -q '^name = "rustls-webpki"$' Cargo.lock || {
  echo "ERROR: rustls-webpki is not in Cargo.lock; re-check the CVE-2026-111943 guard" >&2
  exit 1
}
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is in Cargo.lock" >&2
  exit 1
fi

cargo build --locked --release
mkdir -p "$OUTPUT_DIR/usr/bin"
cp "target/release/xh" "$OUTPUT_DIR/usr/bin/"
