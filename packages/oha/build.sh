#!/bin/bash
set -euo pipefail

export CC=gcc
export CXX=g++
export LD=gcc
# Reproducibility: codegen-units=1 and v0 mangling (the default parallel codegen emits
# functions in a different order every build; legacy mangling hashes the session into
# symbol names; see cargo-mutants, codex, nushell), plus both source and cargo-home paths
# remapped out of the binary. The C libraries cargo builds (aws-lc, jemalloc, SQLite) get
# the same prefix maps through CFLAGS.
export RUSTFLAGS="-C linker=gcc -C codegen-units=1 -C symbol-mangling-version=v0 --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CFLAGS="-O2 -ffile-prefix-map=$(pwd)=/builddir -ffile-prefix-map=$HOME/.cargo=/cargo -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export CARGO_INCREMENTAL=0

# RUSTSEC-2026-0592: url 2.5.9 (see build.ncl). Applied by name, so a stale patch fails the
# build; then prove it landed, fail-closed: no url below 2.5.9 is locked.
patch -Np1 -i ./rustsec-2026-0592-url-lock.patch
if grep -A1 '^name = "url"$' Cargo.lock | grep -qE '^version = "(0[.]|1[.]|2[.]([0-4][.]|5[.][0-8]"))'; then
  echo "ERROR: url below its security floor 2.5.9 is in Cargo.lock (RUSTSEC-2026-0592)" >&2
  exit 1
fi

# All network access happens here, with real entropy: crates are fetched and checked
# against the (patched) Cargo.lock before the shim below is loaded.
cargo fetch --locked

# Deterministic build-time entropy (packages/detbuild) for the offline build only;
# `--frozen` refuses any network access.
LD_PRELOAD=/usr/lib/minimal/libdetbuild.so cargo build --frozen --release --bin oha

install -Dm755 target/release/oha "$OUTPUT_DIR/usr/bin/oha"

# runtime_deps is glibc + libgcc (libgcc_s, for unwinding); fail closed if the binary
# ever NEEDs anything else.
needed=$(readelf -d "$OUTPUT_DIR/usr/bin/oha" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')
echo "$needed"
if grep -vxE 'libc\.so\.6|libm\.so\.6|libgcc_s\.so\.1|ld-linux-(x86-64|aarch64)\.so\.[12]' <<<"$needed"; then
  echo "ERROR: oha NEEDs a library outside glibc and libgcc_s (above)" >&2
  exit 1
fi
