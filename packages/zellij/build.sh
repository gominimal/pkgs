#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"
export OPENSSL_DIR=/usr
export OPENSSL_NO_VENDOR=1

if [ -d /cargo-vendor ]; then
    mkdir -p .cargo
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    cargo build --offline --frozen --release
else
    cargo build --release
fi

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/zellij $OUTPUT_DIR/usr/bin/zellij
