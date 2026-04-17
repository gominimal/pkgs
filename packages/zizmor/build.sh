#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release --package zizmor

install -D -m 0755 target/release/zizmor "$OUTPUT_DIR/usr/bin/zizmor"
