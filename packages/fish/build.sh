#!/bin/sh
set -e

mkdir build && cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# Cargo build scripts expect 'cc'; create symlink to gcc
mkdir -p /tmp/bin
ln -sf "$(command -v gcc)" /tmp/bin/cc
export PATH="/tmp/bin:$PATH"

cmake -D CMAKE_INSTALL_PREFIX=/usr       \
      -D CMAKE_BUILD_TYPE=Release        \
      -D FISH_USE_SYSTEM_PCRE2=ON        \
      -D WITH_DOCS=OFF                   \
      -G Ninja ..
ninja
DESTDIR="$OUTPUT_DIR" ninja install
