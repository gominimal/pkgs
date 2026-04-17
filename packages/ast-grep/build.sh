#!/bin/sh
set -ex

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release -p ast-grep

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/ast-grep $OUTPUT_DIR/usr/bin/
