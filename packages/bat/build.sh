#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

if [ -d /cargo-vendor ]; then
    # macOS AppleDouble files (._*) get embedded when the vendor tarball
    # is created on a Mac. They break libgit2-sys's build.rs which tries
    # to compile them as C (gcc errors on "._realpath.c" etc).
    # Cheap fix: strip them before cargo starts. Long-term: re-vendor with
    # COPYFILE_DISABLE=1 on the staging host (see orch task #91/#93).
    find /cargo-vendor -name '._*' -delete 2>/dev/null || true

    # DIAGNOSTIC 2026-05-28 (orch known-broken: bat AppleDouble persists).
    # find -delete runs successfully (visible above in set -x trace) and
    # the tarball has 0 ._* files, yet gcc still receives ._realpath.c
    # at compile time. Hypothesis: cargo copies the vendored crate to a
    # build-local dir (e.g. cargo's registry/src cache) that the find
    # doesn't reach. These echoes will reveal the actual on-disk paths.
    # Remove once the root cause is fixed.
    echo "=== bat diagnostic: post find-delete state ==="
    echo "--- ._* still in /cargo-vendor? ---"
    find /cargo-vendor -name '._*' 2>/dev/null | head -20 || true
    echo "--- libgit2-sys unix dir contents ---"
    ls -la /cargo-vendor/libgit2-sys/libgit2/src/util/unix/ 2>/dev/null | head -20 || true
    echo "--- where else does ._realpath.c live on the whole rootfs? ---"
    find / -name '._realpath.c' 2>/dev/null | head -20 || true
    echo "--- cargo registry / build dir state ---"
    ls -la /root/.cargo 2>/dev/null | head || true
    ls -la /state/home/.cargo 2>/dev/null | head || true
    echo "=== end diagnostic ==="

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
    RUSTONIG_DYNAMIC_LIBONIG=1 cargo build --offline --frozen --release
else
    RUSTONIG_DYNAMIC_LIBONIG=1 cargo build --release
fi

install -D -m 0755 target/release/bat $OUTPUT_DIR/usr/bin/bat
install -D -m 0755 target/release/build/bat-*/out/assets/completions/bat.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/bat"
