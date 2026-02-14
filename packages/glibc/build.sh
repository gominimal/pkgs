#!/bin/sh
set -e

tar xf "glibc-${MINIMAL_ARG_VERSION}.tar.xz"
cd "glibc-${MINIMAL_ARG_VERSION}"

mkdir -v build
cd build

echo "rootsbindir=/usr/sbin" > configparms

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

../configure --prefix=/usr                  \
            --disable-werror                \
            --disable-nscd                  \
            libc_cv_slibdir=/usr/lib        \
            --enable-stack-protector=strong \
            --enable-kernel=6.1

make -j$(nproc)
# TODO way too slow
# make check
make DESTDIR=$OUTPUT_DIR install

sed '/RTLDLIST=/s@/usr@@g' -i $OUTPUT_DIR/usr/bin/ldd

mkdir -vp $OUTPUT_DIR/usr/lib/locale
localedef --prefix=$OUTPUT_DIR -i en_US -f ISO-8859-1 en_US
localedef --prefix=$OUTPUT_DIR -i en_US -f UTF-8 en_US.UTF-8
