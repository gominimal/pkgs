#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release -p typst-cli

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/typst $OUTPUT_DIR/usr/bin/typst
