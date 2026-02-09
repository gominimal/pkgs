#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release

install -D -m 0755 target/release/railway "$OUTPUT_DIR/usr/bin/railway"
