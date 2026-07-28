#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/just $OUTPUT_DIR/usr/bin/just

mkdir -p $OUTPUT_DIR/usr/share/bash-completion/completions
target/release/just --completions bash > $OUTPUT_DIR/usr/share/bash-completion/completions/just
