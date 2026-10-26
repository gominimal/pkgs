#!/bin/sh
set -ex

tar -xof uv-${MINIMAL_ARG_VERSION}.tar.gz
cd uv-${MINIMAL_ARG_VERSION}

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# >>> pkgmgr lock-patch (generated; regenerate with `pkgmgr lock-patch uv`, never edit)
# security-floors-lock.patch is a cargo-resolved delta against upstream's Cargo.lock; it is
# only valid for the exact lock it was generated from.
echo "3fd592a70bd1c1a83efd3f9191945e57243f26b34a241fe8d4182b5c04258a1b  Cargo.lock" | sha256sum -c --status - || {
  echo "ERROR: upstream Cargo.lock changed; run: pkgmgr lock-patch uv" >&2
  exit 1
}
patch -Np1 -i ../security-floors-lock.patch
# Security floors (version-agnostic): no locked version below a fixed release.
if grep -A1 '^name = "zstd"$' Cargo.lock | grep -qE '^version = "0[.]14[.](([0-2])([-+][^"]*)?|3-[^"]*)"$'; then
  echo "ERROR: zstd below its security floor 0.14.3 is in Cargo.lock (RUSTSEC-2026-0391)" >&2
  exit 1
fi
if grep -A1 '^name = "zstd-safe"$' Cargo.lock | grep -qE '^version = "(8[.]2[.]0-[^"]*|8[.]0[.][0-9]+([-+][^"]*)?)"$'; then
  echo "ERROR: zstd-safe below its security floor 8.2.0 is in Cargo.lock (RUSTSEC-2026-0398, RUSTSEC-2026-0403)" >&2
  exit 1
fi
if grep -A1 '^name = "zstd-sys"$' Cargo.lock | grep -qE '^version = "2[.]1[.](([0-1])([-+][^"]*)?|2-[^"]*)"$'; then
  echo "ERROR: zstd-sys below its security floor 2.1.2 is in Cargo.lock (RUSTSEC-2026-0410)" >&2
  exit 1
fi
# <<< pkgmgr lock-patch

# Security floor (data/security_floors.toml): kept by pkgmgr when the lock
# patch it guarded became unnecessary. No pre-fix version may be locked.
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

cargo build --locked --release

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/uv $OUTPUT_DIR/usr/bin/uv
