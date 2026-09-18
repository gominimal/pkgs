#!/bin/sh
set -ex
export CARGO_INCREMENTAL=0
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

# default-no-update is upstream's recommended feature set for distributors:
# drops the self-update machinery (and its network/TLS deps) that makes no
# sense for a package-managed binary.
cargo build --release --locked -p cargo-nextest --no-default-features --features default-no-update

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/cargo-nextest $OUTPUT_DIR/usr/bin
