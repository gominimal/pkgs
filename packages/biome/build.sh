#!/bin/sh
set -ex

export CC=gcc
export LD=gcc
# biome_cli's Cargo version is "0.0.0"; upstream stamps the real one via this
# env var at compile time (`option_env!("BIOME_VERSION")` in crates/biome_cli
# and crates/biome_configuration). Without it the binary reports 0.0.0 and
# warns on every config `$schema`. See gominimal/pkgs#637.
export BIOME_VERSION="$MINIMAL_ARG_VERSION"
# Upstream's .cargo/config.toml sets `[profile.release] lto = true` (fat LTO), which
# runs the whole crate graph's final optimisation on one core. Thin LTO keeps
# cross-crate inlining and runs in parallel; it is reproducible because of the
# detbuild entropy shim on the build below (same recipe as codex, pkgs#1713).
# v0 mangling: the legacy scheme's per-instance hashes are the other source of
# symbol-order churn (the nushell / difftastic fix, gominimal/inbox#253).
export CARGO_PROFILE_RELEASE_LTO=thin
export RUSTFLAGS="-C linker=gcc -C symbol-mangling-version=v0 --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

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

# All network access happens here, with real entropy: crates are fetched (and
# checked against Cargo.lock) before the shim below is loaded, so no TLS session
# runs with the shim's fixed bytes. No build script biome_cli reaches downloads
# anything (checked for 2.6.9), so the build below needs no network.
cargo fetch --locked

# Deterministic build-time entropy (packages/detbuild): interposes getrandom /
# getentropy so build.rs / proc-macro / rustc-internal HashMaps iterate in the same
# order every build. It wraps only the offline BUILD (`--frozen` refuses any network
# access); the produced binary is unaffected.
LD_PRELOAD=/usr/lib/minimal/libdetbuild.so cargo build --frozen --release -p biome_cli

# For comparing two builds of the same spec (the reproducibility check).
echo "biome binary: $(sha256sum target/release/biome | cut -d' ' -f1) $(stat -c %s target/release/biome) bytes"

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/biome $OUTPUT_DIR/usr/bin/
