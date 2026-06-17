#!/bin/sh
set -ex
export CARGO_INCREMENTAL=0
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo -C codegen-units=1"
export CONST_RANDOM_SEED=0   # pin ahash/const-random compile-time seed

cargo build --release --locked

mkdir -p $OUTPUT_DIR/usr/bin
ls -lah target/release
cp target/release/hex-patch $OUTPUT_DIR/usr/bin
