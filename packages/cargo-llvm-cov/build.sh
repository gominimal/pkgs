#!/bin/sh
set -ex

V="${MINIMAL_ARG_VERSION:?build.ncl forwards version}"
# The crates.io .crate, not the GitHub tag archive: upstream does not commit a
# Cargo.lock, and the published crate carries the one `cargo publish` resolved,
# so --locked builds exactly the tree upstream released.
tar -xzof "cargo-llvm-cov-$V.crate"
cd "cargo-llvm-cov-$V"

export CC=gcc
export LD=gcc
export CARGO_INCREMENTAL=0
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release --locked --bin cargo-llvm-cov

install -D -m 0755 target/release/cargo-llvm-cov "$OUTPUT_DIR/usr/bin/cargo-llvm-cov"
