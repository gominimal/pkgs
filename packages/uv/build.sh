#!/bin/sh
set -ex

tar xf uv-0.9.3.tar.gz
cd uv-0.9.3

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/uv $OUTPUT_DIR/usr/bin/uv
