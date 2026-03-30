#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release --no-default-features

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/fd $OUTPUT_DIR/usr/bin/fd
