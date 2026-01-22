#!/bin/sh
set -e

tar xfo "pcre2-${MINIMAL_ARG_VERSION}.tar.bz2"
cd "pcre2-${MINIMAL_ARG_VERSION}"

# TODO
# --enable-pcre2test-libreadline

export CFLAGS="-march=x86-64-v3 -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr                          \
            --docdir=/usr/share/doc/pcre2-10.45     \
            --enable-unicode                        \
            --enable-jit                            \
            --enable-pcre2-16                       \
            --enable-pcre2-32                       \
            --enable-pcre2grep-libz                 \
            --enable-pcre2grep-libbz2               \
            --disable-static

make -j$(nproc)
# make check
make DESTDIR=$OUTPUT_DIR install
