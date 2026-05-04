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

# Force cargo to use the source tree's vendored deps (vendor/) rather
# than reaching out to crates.io. The source ships a `.cargo/config.toml`
# that already configures vendored sources, but the persistent
# CARGO_HOME (env_state_wiring with prefix=cargo in build.ncl) can carry
# over a config from a previous build that re-registers crates.io.
# Without this, rust 1.95 picked up bytemuck-1.25.0 from crates.io
# instead of the vendored bytemuck-1.13.1, and the newer bytemuck failed
# to build under the bootstrap rustc. CARGO_NET_OFFLINE only affects
# cargo subprocesses; x.py's stage0 download (separate HTTP fetch) is
# unaffected.
export CARGO_NET_OFFLINE=true

./x.py build

DESTDIR=$OUTPUT_DIR ./x.py install

rm $OUTPUT_DIR/usr/bin/rust-gdbgui
