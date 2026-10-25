#!/bin/sh
set -ex

tar -xof uv-${MINIMAL_ARG_VERSION}.tar.gz
cd uv-${MINIMAL_ARG_VERSION}

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# Security floor (data/security_floors.toml): kept by pkgmgr when the lock
# patch it guarded became unnecessary. No pre-fix version may be locked.
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

cargo build --locked --release

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/uv $OUTPUT_DIR/usr/bin/uv
