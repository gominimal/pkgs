#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --locked --release

mkdir -p $OUTPUT_DIR/usr/bin
ls -lah target/release
cp target/release/brush $OUTPUT_DIR/usr/bin
