#!/bin/sh
set -ex
export CARGO_INCREMENTAL=0
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release --locked

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/tuicr $OUTPUT_DIR/usr/bin
