#!/bin/sh
set -ex
export CARGO_INCREMENTAL=0
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release --locked

mkdir -p $OUTPUT_DIR/usr/bin
ls -lah target/release
cp target/release/hex-patch $OUTPUT_DIR/usr/bin
