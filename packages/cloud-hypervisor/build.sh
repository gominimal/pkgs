#!/bin/sh
set -ex

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0
export OPENSSL_DIR=/usr
export OPENSSL_NO_VENDOR=1

FEATURES="kvm,io_uring,guest_debug,ivshmem,pvmemcontrol,fw_cfg"

if [ "$(uname -m)" = "x86_64" ]; then
  FEATURES="${FEATURES},tdx"
fi

cargo build --release --features "$FEATURES"

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/cloud-hypervisor $OUTPUT_DIR/usr/bin/
cp target/release/ch-remote $OUTPUT_DIR/usr/bin/
