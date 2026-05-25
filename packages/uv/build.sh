#!/bin/sh
set -ex

tar -xof uv-${MINIMAL_ARG_VERSION}.tar.gz
cd uv-${MINIMAL_ARG_VERSION}

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

if [ -d /cargo-vendor ]; then
    mkdir -p .cargo
    if [ -f /cargo-vendor/.cargo-config.toml ]; then
        cp /cargo-vendor/.cargo-config.toml .cargo/config.toml
    else
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    fi
    cargo build --offline --frozen --release
else
    cargo build --release
fi

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/uv $OUTPUT_DIR/usr/bin/uv
