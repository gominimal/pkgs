#!/bin/sh
set -ex
export CARGO_INCREMENTAL=0
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

if [ -d /cargo-vendor ]; then
    mkdir -p .cargo
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    cargo build --offline --frozen --release --locked
else
    cargo build --release --locked
fi

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/difft $OUTPUT_DIR/usr/bin
