#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/yazi $OUTPUT_DIR/usr/bin
