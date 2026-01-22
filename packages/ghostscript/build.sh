#!/bin/sh
set -e

# Remove source trees for libraries which are bundled but we build separately
rm -rf freetype lcms2mt jpeg libpng openjpeg

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
            --disable-static \
            --with-system-libtiff \
            --disable-compiler-inits \
            CFLAGS="${CFLAGS:--g -O3} -fPIC"

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
