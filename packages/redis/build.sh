#!/bin/sh
set -ex

export CC=gcc
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

# The aarch64 bedrock toolchain ships without LTO (its sealed binutils ld is static-musl and
# cannot load linker plugins; a plugin-capable glibc-linked rung is future work — the disarmed
# R12-GATE-LTO in that rung's recipe is the re-enable acceptance test). redis auto-enables
# -flto at -O3; disable it via redis's own ENABLE_LTO variable. amd64 keeps LTO.
case "$(uname -m)" in aarch64) LTO="ENABLE_LTO=" ;; *) LTO="" ;; esac
make -j$(nproc) PREFIX=/usr MALLOC=libc $LTO

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 src/redis-server $OUTPUT_DIR/usr/bin/redis-server
install -m 755 src/redis-cli $OUTPUT_DIR/usr/bin/redis-cli
install -m 755 src/redis-benchmark $OUTPUT_DIR/usr/bin/redis-benchmark
cp -a src/redis-check-aof $OUTPUT_DIR/usr/bin/redis-check-aof
cp -a src/redis-check-rdb $OUTPUT_DIR/usr/bin/redis-check-rdb
