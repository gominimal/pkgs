#!/bin/sh
set -ex

export CC=gcc
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe"

make -j$(nproc) PREFIX=/usr MALLOC=libc

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 src/redis-server $OUTPUT_DIR/usr/bin/redis-server
install -m 755 src/redis-cli $OUTPUT_DIR/usr/bin/redis-cli
install -m 755 src/redis-benchmark $OUTPUT_DIR/usr/bin/redis-benchmark
cp -a src/redis-check-aof $OUTPUT_DIR/usr/bin/redis-check-aof
cp -a src/redis-check-rdb $OUTPUT_DIR/usr/bin/redis-check-rdb
