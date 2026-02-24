#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cd daemon
cargo build --release

install -D -m 0755 target/release/teamtype "$OUTPUT_DIR/usr/bin/teamtype"
