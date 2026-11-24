#!/bin/bash
set -euo pipefail

export CC=gcc
export LD=gcc
# Reproducibility: codegen-units=1 and v0 mangling (the default parallel codegen emits
# functions in a different order every build; legacy mangling hashes the session into
# symbol names; see codex, nushell, zola), plus both source and cargo-home paths
# remapped out of the binary.
export RUSTFLAGS="-C linker=gcc -C codegen-units=1 -C symbol-mangling-version=v0 --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0

# All network access happens here, with real entropy: crates are fetched and checked
# against upstream's Cargo.lock before the shim below is loaded. cargo-mutants has no
# -sys crates and no build script that downloads anything (checked for 27.1.0).
cargo fetch --locked

# Deterministic build-time entropy (packages/detbuild) for the offline build only;
# `--frozen` refuses any network access.
LD_PRELOAD=/usr/lib/minimal/libdetbuild.so cargo build --frozen --release --bin cargo-mutants

install -Dm755 target/release/cargo-mutants "$OUTPUT_DIR/usr/bin/cargo-mutants"

# runtime_deps is glibc + libgcc (libgcc_s, for unwinding); fail closed if the binary
# ever NEEDs anything else.
needed=$(readelf -d "$OUTPUT_DIR/usr/bin/cargo-mutants" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')
echo "$needed"
if grep -vxE 'libc\.so\.6|libm\.so\.6|libgcc_s\.so\.1|ld-linux-(x86-64|aarch64)\.so\.[12]' <<<"$needed"; then
  echo "ERROR: cargo-mutants NEEDs a library outside glibc and libgcc_s (above)" >&2
  exit 1
fi
