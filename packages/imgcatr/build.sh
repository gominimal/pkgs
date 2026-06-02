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
    # --frozen requires a committed Cargo.lock. imgcatr ships none upstream
    # and the vendor tarball didn't carry one, so cargo errored trying to
    # CREATE /build/Cargo.lock under --frozen. Fall back to --offline (no
    # --frozen) when no lock is present: still hermetic — cargo resolves
    # purely from the vendored crate set with zero network — just generates
    # the lock at build time. Keep the strict --frozen path when a lock IS
    # present (most pkgs).
    if [ -f Cargo.lock ]; then
        cargo build --offline --frozen --release
    else
        cargo build --offline --release
    fi
else
    cargo build --release
fi

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/imgcatr $OUTPUT_DIR/usr/bin
