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
    # Root cause for #88 (root-caused 2026-05-27, see memory
    # cs-mirror-cache-persists-dirty-files): the cs-mirror /cargo-vendor
    # mount is a hardlink farm into /root/.cache/minimal/cs-mirror, which
    # is *persistent across builds*. An old cargo-vendor tarball (pre
    # fetcher-VM migration #13) was extracted there with macOS
    # AppleDouble `._*` files; current tarballs are clean but the cached
    # `._*` files are still there and trigger rustc E0761 on sysinfo
    # (`._common` filename pattern shows up alongside real
    # `common.rs` / `common/`).
    #
    # Cheap, idempotent fix: strip them before cargo starts. Same idiom
    # as bat's build.sh. The proper fix is a one-time builder-side
    # cache cleanup, tracked as a follow-up.
    find /cargo-vendor -name '._*' -delete 2>/dev/null || true

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
    export BTM_GENERATE=true
    cargo build --offline --frozen --release
else
    export BTM_GENERATE=true
    cargo build --release
fi

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/btm $OUTPUT_DIR/usr/bin
install -D -m 0755 target/tmp/bottom/completion/btm.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/btm"
