#!/bin/sh
# Auto-bootstrapped from https://github.com/sharkdp/hyperfine (1.20.0, rust) by pkgmgr import-wolfi.
set -eu
export CC=gcc
export LD=gcc
# Reproducibility (per minimal-repro's guide): strip absolute build
# paths (source dir + cargo registry) and disable incremental builds.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0
cargo build --release
mkdir -p "$OUTPUT_DIR/usr/bin"
cp "target/release/hyperfine" "$OUTPUT_DIR/usr/bin/"
