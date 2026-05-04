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

# Isolate cargo state to a fresh per-build directory. The build.ncl
# env_state_wiring persists CARGO_HOME across builds with prefix=cargo,
# which means a stale config / registry index / Cargo.lock from a
# previous build can override the source's `.cargo/config.toml`. That's
# how rust 1.95 picked up bytemuck-1.25.0 from crates.io instead of the
# vendored bytemuck-1.13.1: the vendored-sources mapping was being
# clobbered by the persistent CARGO_HOME's own config.
#
# Override CARGO_HOME locally to a fresh tmpdir so the source's
# `.cargo/config.toml` is authoritative and cargo has no prior state to
# fall back on. CARGO_NET_OFFLINE is belt-and-suspenders — with an
# isolated CARGO_HOME and vendor/ properly configured, network shouldn't
# be reached anyway. x.py's stage0 download is a separate HTTP fetch
# (not via cargo), so neither setting affects it.
CARGO_HOME_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$CARGO_HOME_TMPDIR"' EXIT
export CARGO_HOME="$CARGO_HOME_TMPDIR"
export CARGO_NET_OFFLINE=true

./x.py build

DESTDIR=$OUTPUT_DIR ./x.py install

rm $OUTPUT_DIR/usr/bin/rust-gdbgui
