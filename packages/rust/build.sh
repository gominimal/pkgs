#!/bin/sh
set -ex

export LIBSQLITE3_SYS_USE_PKG_CONFIG=1
export LIBSSH2_SYS_USE_PKG_CONFIG=1
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# SEED-ROOTED stage0 (issue #17): use our mrustc-bootstrapped rustc/cargo 1.94.1
# instead of the trust-by-fiat prebuilt.
#
# ⚠ NOT hex0-rooted. This comment previously said "(built from the 229-byte hex0
# seed)" — FALSE, and it shipped in a signed artifact. The seeds were built on an
# UNATTESTED plain GCE VM whose host compiler came from `apt-get install g++`;
# mrustc's own source has no recorded sha. What IS proven is that this CS build
# consumed those tarballs by sha. See build.ncl's header for the full statement.
#
# Their
# version/sha differ from src/stage0's pin (1.94.0), so the build/cache pre-place
# path can't be used; instead extract them and point bootstrap.toml's [build]
# rustc/cargo at them — x.py uses them directly and skips the src/stage0 download
# (no network egress in Confidential Space), exactly as the mrustc chain's rung
# configs do. The seed-rustc tarball bundles its sysroot (bin/rustc + lib/ = std).
mkdir -p seed-stage0/toolchain seed-stage0/cargo-bin
tar xzf ./seed-rustc-*.tar.gz -C seed-stage0/toolchain
tar xzf ./seed-cargo-*.tar.gz -C seed-stage0/cargo-bin
SEED_RUSTC="$(pwd)/seed-stage0/toolchain/bin/rustc"
SEED_CARGO="$(pwd)/seed-stage0/cargo-bin/cargo"
chmod +x "$SEED_RUSTC" "$SEED_CARGO"
echo "rust stage0: SEED-ROOTED $("$SEED_RUSTC" --version)"
# inject the stage0 override right after the [build] table header (order: rustc, cargo)
sed -i "/^\[build\]/a cargo = \"$SEED_CARGO\"" bootstrap.toml
sed -i "/^\[build\]/a rustc = \"$SEED_RUSTC\"" bootstrap.toml

./x.py build

DESTDIR=$OUTPUT_DIR ./x.py install

rm $OUTPUT_DIR/usr/bin/rust-gdbgui
