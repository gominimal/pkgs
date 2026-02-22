#!/bin/sh
set -ex

tar xfo gmp-6.3.0.tar.xz
cd gmp-6.3.0

# Fix GMP's "long long reliability test 1" configure check.
# x86_64: original fix for the x86_64 prebuilt gcc.
# aarch64: the prebuilt gcc 12.4.0 rejects void g(...){} — a variadic
#   function without a named first parameter, invalid before C23 — with
#   "ISO C requires a named argument before '...'", causing configure to
#   think the compiler is buggy. Fix by adding a named first parameter.
case $(uname -m) in
  x86_64)  sed -i '/long long t1;/,+1s/()/(...)/' configure ;;
  aarch64) sed -i 's/void g(\.\.\.)/ void g(int dummy, ...)/g' configure ;;
esac

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr     \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.3.0

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install
