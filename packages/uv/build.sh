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

# System-level uv.toml: trust the system CA store (/etc/ssl/certs) instead of
# the Mozilla roots compiled into uv, so a fix to ca-certificates reaches uv
# without a rebuild (CVE-2026-111943, eMudhra). uv reads /etc/uv/uv.toml as
# its lowest-precedence config (below the user's ~/.config/uv/uv.toml and the
# project's uv.toml). To opt out: --no-system-certs, `system-certs = false` in
# a user or project uv.toml, or UV_NO_SYSTEM_CONFIG=1. UV_SYSTEM_CERTS=false
# does NOT opt out: uv only lets that variable turn the setting on.
# `system-certs` is uv's name since 0.11 (`native-tls` is the deprecated one).
# With it set, uv hands certificate checks to rustls-platform-verifier, which
# on Linux trusts only the system store (/etc/ssl/certs); needs.internet brings
# ca-certificates into every environment uv lands in.
mkdir -p "$OUTPUT_DIR/etc/uv"
cat > "$OUTPUT_DIR/etc/uv/uv.toml" <<'TOML'
# Shipped by Minimal's uv package. Trust the system CA store, so CA
# removals in ca-certificates apply without rebuilding uv.
system-certs = true
TOML
