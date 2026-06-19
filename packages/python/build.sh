#!/bin/sh
set -e

tar -xof "Python-${MINIMAL_ARG_VERSION}.tar.xz"
cd "Python-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Reproducibility: pin libffi's pkg-config vars so configure resolves
# MODULE__CTYPES_LDFLAGS deterministically ('-lffi') rather than letting
# PKG_CHECK_MODULES non-deterministically pick `-L/usr/lib/../lib64` vs
# `-L/usr/lib/../lib` (which leaks into _sysconfigdata*.py/.json/Makefile).
# Both vars must be non-empty or configure falls back to pkg-config.
./configure  --prefix=/usr          \
            --enable-shared         \
            --with-system-expat     \
            --enable-optimizations  \
            --without-static-libpython \
            LIBFFI_CFLAGS="-I/usr/include" \
            LIBFFI_LIBS="-lffi"

make -j$(nproc)
# TODO
#make test TESTOPTS="--timeout 120"
make DESTDIR=$OUTPUT_DIR install
