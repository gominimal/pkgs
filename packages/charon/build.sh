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
VENDOR_TARBALL="$BUILDROOT/charon-vendor-0.1.281.tar.gz"

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

[source."git+https://github.com/Nadrieril/specr?branch=bump-toolchain"]
git = "https://github.com/Nadrieril/specr"
branch = "bump-toolchain"
replace-with = "vendored-sources"

[source."git+https://github.com/Nadrieril/tracing-tree"]
git = "https://github.com/Nadrieril/tracing-tree"
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
CFG

export CARGO_NET_OFFLINE=1
cargo build --offline --release --bin charon --bin charon-driver

# CVE-2026-111943 (eMudhra intermediate key compromise): charon's Cargo.lock pins
# webpki-roots 1.0.9 (trusts emSign ECC Root CA - G3) and rustls-webpki 0.103.4 (no
# eMudhra SPKI block), and the vendor tarball carries both. Neither reaches the binaries:
# the only path is reqwest / crates_io_api, behind charon's optional `popular-crates-test`
# feature, which this default-feature build does not enable. Fail the build if that
# changes, so a TLS stack can't arrive in a charon bump unnoticed. Cargo writes one
# deps/lib<crate>-<hash>.rlib per compiled crate; serde is the positive control (it must
# be found, or this check is looking in the wrong place).
ls target/release/deps/ | grep -qE '^libserde-[0-9a-f]+\.rlib$' || {
  echo "ERROR: no libserde rlib in target/release/deps; the TLS-stack check cannot run" >&2
  exit 1
}
if ls target/release/deps/ | grep -E '^lib(rustls|rustls_webpki|webpki_roots|webpki_root_certs|reqwest)-[0-9a-f]+\.rlib$'; then
  echo "ERROR: charon now compiles a TLS stack. Lock rustls-webpki >= 0.103.16 and webpki-roots >= 1.0.10 (CVE-2026-111943) before shipping" >&2
  exit 1
fi

install -Dm755 target/release/charon "$OUTPUT_DIR/usr/bin/charon"
install -Dm755 target/release/charon-driver "$OUTPUT_DIR/usr/bin/charon-driver"
