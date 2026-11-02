#!/bin/sh
set -ex

# Security backport (see build.ncl). `set -e` plus patch's non-zero exit on a
# rejected hunk means a stale patch aborts the build instead of silently
# shipping an unpatched `typst init`.
patch -Np1 -i GHSA-rw6x-h3xm-cvq5.patch
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release -p typst-cli

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/typst $OUTPUT_DIR/usr/bin/typst
