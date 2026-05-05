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

# --- Diagnostics: 1.95 build keeps fetching bytemuck-1.25.0 from
# crates.io instead of using the vendored bytemuck-1.13.1. We need
# to see which cargo invocation is the offender. The error output
# we've seen so far is mid-stream rustc errors; what we don't know
# is which sub-build triggered the resolution.
echo "===== rust build env ====="
echo "HOME=$HOME"
echo "CARGO_HOME=${CARGO_HOME:-<unset>}"
echo "PWD=$PWD"
echo "uname -m=$(uname -m)"
echo "===== /rust build env ====="
echo
echo "===== source-tree .cargo/config.toml ====="
if [ -f .cargo/config.toml ]; then cat .cargo/config.toml; else echo "<missing>"; fi
echo "===== /source-tree .cargo/config.toml ====="
echo
echo "===== source-tree vendor/ summary ====="
if [ -d vendor ]; then
  ls vendor/bytemuck* 2>/dev/null || echo "no vendored bytemuck-*"
  echo "vendor/ entry count: $(ls vendor 2>/dev/null | wc -l)"
else
  echo "<no vendor dir>"
fi
echo "===== /source-tree vendor/ summary ====="
echo

# `--verbose --verbose` makes x.py print every cargo invocation
# with full args, so we can see which sub-build triggers
# bytemuck-1.25.0 download. CARGO_LOG=...resolver=trace adds
# resolver decisions (which Cargo.lock, which sources considered).
export CARGO_LOG="cargo::core::resolver=info,cargo::sources::registry=info"
./x.py build --verbose --verbose

DESTDIR=$OUTPUT_DIR ./x.py install

rm $OUTPUT_DIR/usr/bin/rust-gdbgui
