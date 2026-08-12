#!/bin/sh
set -ex

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

# Upstream's release profile uses fat LTO, which OOMs the build sandbox
# linking the final binary; thin LTO fits in memory.
export CARGO_PROFILE_RELEASE_LTO=thin

cargo build --release -p biome_cli

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/biome $OUTPUT_DIR/usr/bin/
