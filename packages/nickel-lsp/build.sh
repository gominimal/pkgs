#!/bin/sh
set -ex

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
    cargo build --offline --frozen --release -p nickel-lang-lsp
else
    cargo build --release -p nickel-lang-lsp
fi

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/nls $OUTPUT_DIR/usr/bin/
