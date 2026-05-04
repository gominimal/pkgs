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

# --- Cargo state isolation + diagnostics ---
#
# Background: rust 1.95 builds kept failing on bytemuck-1.25.0 errors
# even though the source vendors bytemuck-1.13.1. The error path
# (`/state/home/.cargo/registry/src/index.crates.io-*/bytemuck-1.25.0/`)
# pointed at a poisoned persistent CARGO_HOME (state-wired in
# build.ncl with prefix=cargo). Two prior attempts didn't fix it:
# `CARGO_NET_OFFLINE=true` alone (doesn't bypass cached registry
# entries) and `CARGO_HOME=$(mktemp -d)` (didn't take effect — error
# path stayed at /state/home, suggesting either x.py overrides
# CARGO_HOME or the sandbox bind-mounts /state/home so the path
# persists regardless of our env).
#
# Defensive layered approach:
#   1. Wipe the persistent registry cache outright. If the sandbox
#      really does bind-mount /state/home, this clears the poison
#      from the source rather than redirecting around it.
#   2. Pin CARGO_HOME inside the source tree (always writable in
#      the sandbox, no $TMPDIR ambiguity) — gives cargo a fresh,
#      writable state dir guaranteed to be ours.
#   3. Diagnostics: log env state so we can see what cargo sees.
echo "--- pre-build cargo env ---"
echo "HOME=$HOME"
echo "TMPDIR=${TMPDIR:-<unset>}"
echo "CARGO_HOME (incoming)=${CARGO_HOME:-<unset>}"
echo "PWD=$PWD"
if [ -d "$HOME/.cargo/registry/src" ]; then
  echo "wiping persistent $HOME/.cargo/registry/src to clear poisoned bytemuck-1.25.0"
  rm -rf "$HOME/.cargo/registry/src" "$HOME/.cargo/registry/cache" || true
fi

CARGO_HOME_LOCAL="$PWD/.cargo-home-fresh"
mkdir -p "$CARGO_HOME_LOCAL"
export CARGO_HOME="$CARGO_HOME_LOCAL"
export CARGO_NET_OFFLINE=true
echo "CARGO_HOME (effective)=$CARGO_HOME"
echo "--- /pre-build cargo env ---"

./x.py build

DESTDIR=$OUTPUT_DIR ./x.py install

rm $OUTPUT_DIR/usr/bin/rust-gdbgui
