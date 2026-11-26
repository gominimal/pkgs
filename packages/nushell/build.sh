#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
# symbol-mangling-version=v0: the default (legacy) mangling appends a hash to
# each monomorphized generic; for a few instances (Vec::extend_desugared, Vec as
# Debug/Drop, ...) that hash came out non-deterministic build-to-build. Since
# rustc places codegen items in symbol-name order, those differing names shuffled
# addresses and cascaded into a ~10% size-preserving .text/.rela.dyn reordering.
# v0 mangling is structural (no hash) -> deterministic by construction.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo -C symbol-mangling-version=v0"
export CONST_RANDOM_SEED=0   # pin ahash/const-random compile-time seed

# Upstream's release profile (lto = "thin", default codegen units) is kept. It is
# reproducible because of the detbuild entropy shim on the build below; ThinLTO's
# `.llvm.<hash>` names churned without it (gominimal/inbox#253). This
# script used to turn LTO off and force codegen-units=1 (in RUSTFLAGS and the
# profile) for that (pkgs#254, #292; #292 also added the shim), and as with codex
# (pkgs#1713) the shim is the part that matters. Don't put them back for
# reproducibility; compare two builds' sha256 (echoed below) instead.

# Security floor (data/security_floors.toml): kept by pkgmgr when the lock
# patch it guarded became unnecessary. No pre-fix version may be locked.
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

# All network access happens here, with real entropy: crates are fetched (and
# checked against Cargo.lock) before the shim below is loaded, so no TLS session
# runs on the shim's fixed bytes. This build has the network through `rust`,
# which declares needs.internet. No build script in the dependency graph
# downloads anything (checked for 0.117.0), so the build below needs no network.
cargo fetch --locked

# Deterministic build-time entropy (packages/detbuild, replacing the copy of the
# shim this script used to compile): interposes getrandom/getentropy so build.rs /
# proc-macro / rustc-internal HashMaps iterate identically every build. Scoped to
# the cargo build only, and that build stays offline: `--frozen` refuses any
# network access. The produced binary is unaffected.
LD_PRELOAD=/usr/lib/minimal/libdetbuild.so cargo build --frozen --release

# For comparing two builds of the same spec (the reproducibility check).
echo "nu binary: $(sha256sum target/release/nu | cut -d' ' -f1) $(stat -c %s target/release/nu) bytes"

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/nu $OUTPUT_DIR/usr/bin/nu
