#!/bin/sh
# Imported from Wolfi `zola` (0.22.1, rust) by pkgmgr import-wolfi.
set -eu
export CC=gcc
export LD=gcc
# Reproducibility (per minimal-repro's guide): strip absolute build paths
# (source dir + cargo registry), disable incremental builds, and pin codegen.
#
# codegen-units=1 is the load-bearing one here. rustc's default release build
# shards codegen across parallel units, and the units finish in whatever order
# the thread pool happens to produce, so functions are EMITTED in a different
# order each build. The result is a binary of identical size whose contents are
# a permutation of themselves — measured on 0.22.1: 16.89% of bytes differed
# with the total size unchanged, and 69% of the differing windows had a
# byte-exact twin elsewhere in the other build. Not codegen variance; ordering.
#
# symbol-mangling-version=v0 removes the other half: the legacy mangling scheme
# embeds a compilation-session hash in symbol names, which varies run to run.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo -C codegen-units=1 -C symbol-mangling-version=v0"
export CARGO_INCREMENTAL=0
cargo build --release
mkdir -p "$OUTPUT_DIR/usr/bin"
cp "target/release/zola" "$OUTPUT_DIR/usr/bin/"
