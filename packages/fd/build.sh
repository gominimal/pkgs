#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release --no-default-features

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/fd $OUTPUT_DIR/usr/bin/fd
