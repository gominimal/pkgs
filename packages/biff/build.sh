#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
ls -lah target/release
# Upstream renamed the crate/binary biff -> bttf (BurntSushi/biff -> bttf), so
# cargo now emits target/release/bttf. Install it under the package's `biff`
# command name (the output glob is usr/bin/biff).
cp target/release/bttf $OUTPUT_DIR/usr/bin/biff
