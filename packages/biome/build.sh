#!/bin/sh
set -ex

export CC=gcc
export LD=gcc
# biome_cli's Cargo version is "0.0.0"; upstream stamps the real one via this
# env var at compile time (`option_env!("BIOME_VERSION")` in crates/biome_cli
# and crates/biome_configuration). Without it the binary reports 0.0.0 and
# warns on every config `$schema`. See gominimal/pkgs#637.
export BIOME_VERSION="$MINIMAL_ARG_VERSION"
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release -p biome_cli

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/biome $OUTPUT_DIR/usr/bin/
