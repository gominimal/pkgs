#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release --bin atuin

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/atuin $OUTPUT_DIR/usr/bin/atuin
