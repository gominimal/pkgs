#!/bin/bash
set -euo pipefail

# Source unpacks into cwd via `extract = true` + `strip_prefix` in
# build.ncl — no explicit `cd` needed.

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CFLAGS="-O2 -pipe -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"

cargo build --release --locked --bin maki

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/maki $OUTPUT_DIR/usr/bin/maki
