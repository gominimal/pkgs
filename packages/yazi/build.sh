#!/bin/sh
set -ex
export CARGO_INCREMENTAL=0
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release --locked

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/yazi $OUTPUT_DIR/usr/bin
