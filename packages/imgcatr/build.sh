#!/bin/sh
set -ex
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
    # Restore the lockfile resolved at vendor time when the upstream
    # source ships none (tiny crates often don't commit Cargo.lock).
    # It pins exactly the vendored crate versions, so --frozen stays
    # reproducible. No-op when the source already has a Cargo.lock.
    if [ -f /cargo-vendor/Cargo.lock ] && [ ! -f Cargo.lock ]; then
        cp /cargo-vendor/Cargo.lock Cargo.lock
    fi
    cargo build --offline --frozen --release
else
    cargo build --release
fi

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/imgcatr $OUTPUT_DIR/usr/bin
