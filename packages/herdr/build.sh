#!/bin/sh
# Auto-bootstrapped from https://github.com/herdrdev/herdr (0.9.1, rust) by pkgmgr import github.
set -eu
export CC=gcc
export LD=gcc
# Reproducibility (per minimal-repro's guide): strip absolute build
# paths (source dir + cargo registry) and disable incremental builds.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0
# herdr vendors libghostty-vt, whose build.rs shells out to Zig and looks
# for it on PATH or via $ZIG. It pins Zig 0.16.0 and refuses anything else;
# we ship exactly that.
export ZIG="$(command -v zig)"
cargo build --release
mkdir -p "$OUTPUT_DIR/usr/bin"
cp "target/release/herdr" "$OUTPUT_DIR/usr/bin/"
