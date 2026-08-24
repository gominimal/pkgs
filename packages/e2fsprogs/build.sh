#!/bin/sh
set -e

tar -xof "e2fsprogs-${MINIMAL_ARG_VERSION}.tar.xz"
cd "e2fsprogs-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Defer libblkid/libuuid (and uuidd) to util-linux, which is injected into this
# build via runtime_deps. e2fsprogs bundles its own older forks of libblkid and
# libuuid with the same soname (libblkid.so.1, libuuid.so.1) as util-linux's
# maintained, symbol-versioned ones; shipping both in a single image makes the
# dynamic loader resolve util-linux's libmount against the wrong libblkid and
# warn "no version information available". Building --disable-libblkid
# --disable-libuuid links e2fsprogs's own tools against util-linux's libs (an
# ABI superset), so the image carries exactly one libblkid/libuuid. Point
# pkg-config at util-linux's .pc files so configure finds them.
export PKG_CONFIG_PATH="/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

./configure --bindir=/usr/bin       \
            --sbindir=/usr/sbin     \
            --libdir=/usr/lib       \
            --enable-elf-shlibs     \
            --disable-defrag        \
            --disable-libblkid      \
            --disable-libuuid       \
            --disable-uuidd         \
            --without-libintl-prefix

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install
