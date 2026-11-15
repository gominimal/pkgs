#!/bin/sh
set -ex

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0
export OPENSSL_DIR=/usr
export OPENSSL_NO_VENDOR=1

FEATURES="kvm,io_uring,guest_debug,ivshmem,pvmemcontrol,fw_cfg"

# `tdx` (Intel Trust Domain Extensions) is DISABLED as of 53.0: upstream ships a
# hard `compile_error!` guard for it —
#   error: Feature 'tdx' is broken.
#   error: could not compile `cloud-hypervisor` (bin "cloud-hypervisor")
# — so enabling it fails the x86_64 build outright. Re-enable once upstream drops
# the guard; check cloud-hypervisor's release notes on the next version bump.

# >>> pkgmgr lock-patch (generated; regenerate with `pkgmgr lock-patch cloud-hypervisor`, never edit)
# security-floors-lock.patch is a cargo-resolved delta against upstream's Cargo.lock; it is
# only valid for the exact lock it was generated from.
echo "f6d6359f758c59a6b05152a185a2985ccb716bee014076812a71166a5ebca365  Cargo.lock" | sha256sum -c --status - || {
  echo "ERROR: upstream Cargo.lock changed; run: pkgmgr lock-patch cloud-hypervisor" >&2
  exit 1
}
patch -Np1 -i ./security-floors-lock.patch
# Security floors (version-agnostic): no locked version below a fixed release.
if grep -A1 '^name = "rustix"$' Cargo.lock | grep -qE '^version = "1[.]1[.](([0-5])([-+][^"]*)?|6-[^"]*)"$'; then
  echo "ERROR: rustix below its security floor 1.1.6 is in Cargo.lock (RUSTSEC-2026-0486)" >&2
  exit 1
fi
# <<< pkgmgr lock-patch

cargo build --release --features "$FEATURES"

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/cloud-hypervisor $OUTPUT_DIR/usr/bin/
cp target/release/ch-remote $OUTPUT_DIR/usr/bin/
