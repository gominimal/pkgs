#!/usr/bin/bash
set -e

tar xfo gcc-15.2.0.tar.xz
cd gcc-15.2.0

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

mkdir -v build
cd build

# TODO
# --enable-host-pie
# --enable-nls

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

../configure \
             --prefix=/usr                      \
             --libdir=/usr/lib                   \
             --enable-languages=c,c++,fortran   \
             --enable-default-pie     \
             --enable-default-ssp     \
             --disable-multilib       \
             --disable-bootstrap      \
             --disable-fixincludes     \
             --with-system-zlib       \
             --disable-nls

make -j$(nproc)
# TODO make -k check
make DESTDIR=$OUTPUT_DIR install-strip

# TODO
# ln -sf $OUTPUT_DIR/usr/bin/gcc $OUTPUT_DIR/usr/bin/cc
