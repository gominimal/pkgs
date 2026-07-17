#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# 0.9.2 restructured the repo into a Cargo workspace: the old standalone
# `daemon/` crate is now the `crates/teamtype` member. Build the `teamtype` bin
# by name from the workspace root (robust to the layout change) rather than
# `cd`-ing into a hardcoded subdir. The workspace `target/` is at the root.
cargo build --release --bin teamtype

install -D -m 0755 target/release/teamtype "$OUTPUT_DIR/usr/bin/teamtype"
