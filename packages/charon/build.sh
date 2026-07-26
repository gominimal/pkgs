#!/bin/sh
# Build the charon + charon-driver Rust binaries offline against the pinned
# nightly rustc-dev toolchain (rust-nightly-charon → /usr/bin/rustc,cargo) and
# the vendored crate set. See build.ncl for the pin + why rustc_private.
set -eu

# rustc defaults to a `cc` linker the sandbox doesn't have; point it at gcc.
export CC=gcc
export LD=gcc
# Reproducibility (pkgs AGENTS.md, Rust): remap the build path out of debuginfo.
BUILDROOT="$(pwd)"
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$BUILDROOT=/builddir"
export CARGO_HOME="$BUILDROOT/.cargo-home"
VENDOR_TARBALL="$BUILDROOT/charon-vendor-0.1.223.tar.gz"

# The Rust workspace is the repo's charon/ subdir.
cd charon

# Vendored deps → charon/vendor/ (offline; no network).
tar -xof "$VENDOR_TARBALL"

# Keep rust-toolchain(.toml): our real cargo (not a rustup proxy) ignores it, so
# it triggers no toolchain switch — and charon's source `include_str!`s the
# `rust-toolchain` file at compile time, so deleting it breaks the build.

# Point cargo at the vendored sources (crates.io + the two git forks).
mkdir -p .cargo
cat > .cargo/config.toml <<'CFG'
[source.crates-io]
replace-with = "vendored-sources"
[source."git+https://github.com/Nadrieril/serde_state?branch=main"]
git = "https://github.com/Nadrieril/serde_state"
branch = "main"
replace-with = "vendored-sources"
[source."git+https://github.com/Nadrieril/tracing-tree"]
git = "https://github.com/Nadrieril/tracing-tree"
replace-with = "vendored-sources"
[source.vendored-sources]
directory = "vendor"
CFG

export CARGO_NET_OFFLINE=1
cargo build --offline --release --bin charon --bin charon-driver

install -Dm755 target/release/charon "$OUTPUT_DIR/usr/bin/charon"
install -Dm755 target/release/charon-driver "$OUTPUT_DIR/usr/bin/charon-driver"
