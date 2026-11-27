#!/bin/sh
# Imported from Wolfi `zola` (0.22.1, rust) by pkgmgr import-wolfi.
set -eu
export CC=gcc
export LD=gcc
# Reproducibility (per minimal-repro's guide): strip absolute build paths
# (source dir + cargo registry), disable incremental builds, v0 mangling, and the
# detbuild entropy shim on the build below.
#
# Upstream's release profile is fat LTO with codegen-units = 1, which runs the
# whole graph's optimisation on one core. Thin LTO over 16 units is used instead.
# 0.22.1 showed a function-order permutation with parallel codegen (16.89% of
# bytes differing at equal size); pkgs#525 added cgu=1 together with the entropy
# shim. As with codex (pkgs#1713), the shim is the part that matters: with it,
# parallel codegen at thin LTO builds byte-identically. Don't put `-C codegen-units=1` back in
# RUSTFLAGS for reproducibility; compare two builds' sha256 (echoed below) instead.
#
# symbol-mangling-version=v0 removes the other half: the legacy mangling scheme
# embeds a compilation-session hash in symbol names, which varies run to run.
export CARGO_PROFILE_RELEASE_LTO=thin
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo -C symbol-mangling-version=v0"
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
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

# All network access happens here, with real entropy: crates are fetched (and
# checked against Cargo.lock) before the shim below is loaded, so no TLS session
# runs on the shim's fixed bytes. No build script in the dependency graph
# downloads anything (checked for 0.23.6), so the build below needs no network.
cargo fetch --locked

# Deterministic build-time entropy (packages/detbuild, replacing the copy of the
# shim this script used to compile): interposes getrandom/getentropy so build.rs /
# proc-macro / rustc-internal HashMaps iterate identically every build. Runtime
# binary is unaffected. It wraps only the offline BUILD: `--frozen` refuses any
# network access.
LD_PRELOAD=/usr/lib/minimal/libdetbuild.so cargo build --frozen --release

# For comparing two builds of the same spec (the reproducibility check).
echo "zola binary: $(sha256sum target/release/zola | cut -d' ' -f1) $(stat -c %s target/release/zola) bytes"

mkdir -p "$OUTPUT_DIR/usr/bin"
cp "target/release/zola" "$OUTPUT_DIR/usr/bin/"
