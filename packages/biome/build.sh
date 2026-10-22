#!/bin/sh
set -ex

export CC=gcc
export LD=gcc
# biome_cli's Cargo version is "0.0.0"; upstream stamps the real one via this
# env var at compile time (`option_env!("BIOME_VERSION")` in crates/biome_cli
# and crates/biome_configuration). Without it the binary reports 0.0.0 and
# warns on every config `$schema`. See gominimal/pkgs#637.
export BIOME_VERSION="$MINIMAL_ARG_VERSION"
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

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
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

cargo build --locked --release -p biome_cli

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/biome $OUTPUT_DIR/usr/bin/
