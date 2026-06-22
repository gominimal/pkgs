#!/bin/sh
set -ex
export CARGO_INCREMENTAL=0
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo -C codegen-units=1"
export CONST_RANDOM_SEED=0   # pin ahash/const-random compile-time seed

# Reproducibility: build.rs compiles the 11 vendored tree-sitter parsers with
# rayon `parsers.par_iter()`, so each cc::Build::compile() emits its
# cargo:rustc-link-lib directive in non-deterministic completion order. That
# randomizes the LINK ORDER of the parser static libs, so the (huge) parser
# tables land at different addresses each build — distributed .rodata/.text/.data
# differences that codegen-units=1 cannot fix. Serialize parser compilation so
# the link directives are emitted in deterministic source order.
sed -i 's/parsers\.par_iter()\.for_each/parsers.iter().for_each/' build.rs
grep -q 'parsers.iter().for_each' build.rs || { echo "ERROR: difftastic par_iter->iter patch did not apply — build.rs changed" >&2; exit 1; }

cargo build --release --locked

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/difft $OUTPUT_DIR/usr/bin
