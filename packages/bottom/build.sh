#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# Hermetic build path: when /cargo-vendor exists (mounted by a SLSA-grade
# builder that has pre-staged every crate from Cargo.lock as a sha-verified
# vendor tree), redirect crates.io to it and build offline. Otherwise fall
# back to the normal online build for dev iteration. Matches probe-rs's
# build.sh pattern verbatim.
if [ -d /cargo-vendor ]; then
    # DEBUG (2026-05-21): trace the source of the phantom common.rs
    # that rustc reports as duplicating sysinfo/src/common/mod.rs (E0761).
    # Our cargo vendor tarball ONLY contains common/ (no common.rs),
    # but the build sees both — list everything to see where it
    # materializes. Remove this block once #88 is root-caused.
    echo "=== DEBUG #88: sysinfo dir contents ==="
    find /cargo-vendor/sysinfo -name 'common*' -ls 2>&1 || true
    echo "=== DEBUG #88: ls -la sysinfo/src/ ==="
    ls -la /cargo-vendor/sysinfo/src/ 2>&1 || true
    echo "=== DEBUG #88: cargo registry caches? ==="
    find /root/.cargo /root/.rustup -name "sysinfo*" 2>/dev/null | head -10 || true
    echo "=== DEBUG #88: end ==="

    mkdir -p .cargo
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    export BTM_GENERATE=true
    cargo build --offline --frozen --release
else
    export BTM_GENERATE=true
    cargo build --release
fi

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/btm $OUTPUT_DIR/usr/bin
install -D -m 0755 target/tmp/bottom/completion/btm.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/btm"
