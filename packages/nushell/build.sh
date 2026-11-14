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
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo -C codegen-units=1 -C symbol-mangling-version=v0"
export CONST_RANDOM_SEED=0   # pin ahash/const-random compile-time seed

# nushell's Cargo.toml [profile.release] sets lto="thin". ThinLTO's parallel
# backend is non-deterministic — it produces the `.llvm.<hash>` codegen-unit
# locals and section reordering that left `nu` non-reproducible even WITH
# `-C codegen-units=1` (LTO runs on top of codegen units, so that flag can't fix
# it). Override the profile via cargo env (which beats Cargo.toml) to disable LTO;
# codegen-units=1 then yields deterministic codegen. Modest size/perf cost — the
# same reproducibility-over-optimization trade as dropping PGO for python.
export CARGO_PROFILE_RELEASE_LTO=off
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1

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

cat > /tmp/detrand.c <<'CEOF'
#include <stddef.h>
#include <sys/types.h>
ssize_t getrandom(void *buf, size_t len, unsigned int flags) {
    (void)flags;
    for (size_t i = 0; i < len; i++) ((unsigned char *)buf)[i] = 0;
    return (ssize_t)len;
}
int getentropy(void *buf, size_t len) {
    for (size_t i = 0; i < len; i++) ((unsigned char *)buf)[i] = 0;
    return 0;
}
CEOF
gcc -shared -fPIC -O2 -o /tmp/libdetrand.so /tmp/detrand.c

# Scope the shim to the cargo build only — no global export/unset window — and
# keep that build offline: `--frozen` refuses any network access.
LD_PRELOAD=/tmp/libdetrand.so cargo build --frozen --release

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/nu $OUTPUT_DIR/usr/bin/nu
