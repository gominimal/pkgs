#!/bin/sh
# Build gmp with its C++ interface and keep only the C++ files; the C library
# and gmp.h come from the gmp package (see build.ncl).
set -ex

v="${MINIMAL_ARG_VERSION}"

# libgmpxx must match the libgmp it loads at run time: the gmp build dep's.
have=$(awk '/^#define __GNU_MP_VERSION /{a=$3} /^#define __GNU_MP_VERSION_MINOR /{b=$3}
  /^#define __GNU_MP_VERSION_PATCHLEVEL /{c=$3} END{print a "." b "." c}' /usr/include/gmp.h)
[ "$have" = "$v" ] || { echo "gmpxx $v but the gmp build dep is $have; bump both" >&2; exit 1; }

tar -xof "gmp-$v.tar.xz"
cd "gmp-$v"

# The same configure fixes as packages/gmp/build.sh.
case $(uname -m) in
  x86_64)  sed -i '/long long t1;/,+1s/()/(...)/' configure ;;
  aarch64) sed -i 's/void g(\.\.\.)/ void g(int dummy, ...)/g' configure ;;
esac

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -std=gnu17 -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -std=gnu++17 -ffile-prefix-map=$(pwd)=/builddir"

./configure  --prefix=/usr     \
            --enable-cxx     \
            --disable-static

make -j$(nproc)
make check
make DESTDIR="$(pwd)/stage" install

mkdir -p "$OUTPUT_DIR/usr/lib/pkgconfig" "$OUTPUT_DIR/usr/include"
cp -P stage/usr/lib/libgmpxx.so* "$OUTPUT_DIR/usr/lib/"
cp stage/usr/include/gmpxx.h "$OUTPUT_DIR/usr/include/"
cp stage/usr/lib/pkgconfig/gmpxx.pc "$OUTPUT_DIR/usr/lib/pkgconfig/"
