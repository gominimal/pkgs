#!/bin/sh
set -ex
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
# the bundled 2008 config.guess/config.sub predate aarch64: use the modern GNU config scripts (fetched as Sources)
cp gnu-config-config.guess config.guess
cp gnu-config-config.sub config.sub
chmod +x config.guess config.sub
./configure --prefix=/usr
make
make DESTDIR="$OUTPUT_DIR" install
