#!/bin/sh
set -ex

export CC=gcc
export LD=gcc
export BIOME_VERSION="$MINIMAL_ARG_VERSION"
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release -p biome_cli

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/biome $OUTPUT_DIR/usr/bin/
