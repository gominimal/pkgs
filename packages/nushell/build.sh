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

# Determinism shim (fixes a CLASS of Rust non-repro): build-time code — here the
# pest/pest_consume proc-macros generating the parser — seeds std::HashMap from
# getrandom(), whose per-process-random seed makes their CODE-GENERATION order vary
# build-to-build (different Rule discriminants/match-arm order -> different .text).
# std exposes no knob to pin its hasher, so pin the build's entropy itself: an
# LD_PRELOAD that makes getrandom/getentropy deterministic, so every build-time
# HashMap iterates stably. Applies to rustc + all proc-macros for this build only.
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

# Scope the shim to the cargo build only — no global export/unset window.
LD_PRELOAD=/tmp/libdetrand.so cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/nu $OUTPUT_DIR/usr/bin/nu
