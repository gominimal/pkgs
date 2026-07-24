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

# ATTESTED stage0 (issue #17 — the ladder CLOSED): the stage0 rustc/cargo is the CS-attested
# rustc-1.94.1 rung (a build_dep installed at /usr/lib/rustc-1.94.1), NOT the old unattested
# seed-*.tar.gz. x.py uses it directly (bootstrap.toml [build] rustc/cargo) and skips the
# src/stage0 download — no network egress in Confidential Space. See build.ncl's header for the
# full chain and WHY 1.94.1 not the 1.94.0 pin (the tracked_env --cfg=bootstrap skew).
STAGE0_PREFIX=/usr/lib/rustc-1.94.1
SEED_RUSTC="${STAGE0_PREFIX}/bin/rustc"
SEED_CARGO="${STAGE0_PREFIX}/bin/cargo"
[ -x "$SEED_RUSTC" ] || { echo "rust: FATAL attested stage0 rustc missing at $SEED_RUSTC — the rustc-1.94.1 rung is THE anchor of this build" >&2; exit 1; }
[ -x "$SEED_CARGO" ] || { echo "rust: FATAL attested stage0 cargo missing at $SEED_CARGO" >&2; exit 1; }
# x.py parses the stage0 rustc's release (1.94.1) against src/stage0 (pins 1.94.0); 1.94.1 > pin is
# accepted (check_stage0_version = same-or-one-minor) and sidesteps the tracked_env bootstrap skew.
S0V="$("$SEED_RUSTC" --version 2>&1 || true)"
echo "$S0V" | grep -qF "1.94.1" || { echo "rust: FATAL attested stage0 rustc --version = '$S0V', expected 1.94.1" >&2; exit 1; }
echo "rust stage0: CS-ATTESTED rustc-1.94.1 -> $S0V"
# inject the stage0 override right after the [build] table header (order: rustc, cargo)
sed -i "/^\[build\]/a cargo = \"$SEED_CARGO\"" bootstrap.toml
sed -i "/^\[build\]/a rustc = \"$SEED_RUSTC\"" bootstrap.toml

# bootstrap.toml sets `vendor = false` so bootstrap does NOT pass cargo --frozen (see the comment
# there): our attested stage0 cargo 1.94.0 needs a deterministic offline Cargo.lock refresh from
# vendor/ that --frozen would forbid. Belt-and-suspenders: force cargo offline so no path can reach
# the network (there is no CS egress anyway; the .cargo/config.toml vendored-sources redirect keeps
# every crate local).
export CARGO_NET_OFFLINE=true

./x.py build

DESTDIR=$OUTPUT_DIR ./x.py install

rm $OUTPUT_DIR/usr/bin/rust-gdbgui
