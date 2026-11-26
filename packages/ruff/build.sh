#!/bin/sh
# Imported from Wolfi `ruff` (0.17.6, rust) by pkgmgr import-wolfi.
set -eu
export CC=gcc
export LD=gcc
# Reproducibility (per minimal-repro's guide): strip absolute build
# paths (source dir + cargo registry) and disable incremental builds.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0
# Link pkgs' libzstd instead of the copy vendored in zstd-sys (2.1.2+zstd.1.5.7,
# the same zstd as pkgs'), so a fix to pkgs' zstd reaches ruff through the one
# shared library. ruff reaches zstd through ruff_db / ty_vendored -> zip: the
# vendored typeshed zip is zstd-compressed, because the workspace build turns
# on ty_vendored's `zstd` feature (via ty_project). zstd-sys's build script
# panics when pkg-config cannot find libzstd; the NEEDED check below fails
# closed if a bundled copy is ever linked instead.
export ZSTD_SYS_USE_PKG_CONFIG=1
cargo build --release
needed=$(readelf -d target/release/ruff | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
if ! printf '%s\n' "$needed" | grep -q '^libzstd[.]so[.]1$'; then
  echo "ERROR: ruff does not link the system libzstd.so.1 (NEEDED: $(echo $needed))" >&2
  exit 1
fi
mkdir -p "$OUTPUT_DIR/usr/bin"
cp "target/release/ruff" "$OUTPUT_DIR/usr/bin/"
