#!/usr/bin/env bash
set -euo pipefail

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"
export HELIX_DEFAULT_RUNTIME=/usr/lib/helix/runtime
export HELIX_DISABLE_AUTO_GRAMMAR_BUILD=1

cargo build --release --locked

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 target/release/hx "$OUTPUT_DIR/usr/bin/hx"

mkdir -p "$OUTPUT_DIR/usr/lib/helix"
rm -rf runtime/grammars/sources
cp -r runtime "$OUTPUT_DIR/usr/lib/helix/runtime"
