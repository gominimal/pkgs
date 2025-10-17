#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
ls -lah target/release
cp target/release/hexhog $OUTPUT_DIR/usr/bin
