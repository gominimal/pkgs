#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

# Fix SVT-AV1 4.x compatibility: enable_adaptive_quantization was removed
sed -i '/enable_adaptive_quantization/d' libavcodec/libsvtav1.c

./configure --prefix=/usr           \
            --disable-static        \
            --enable-shared         \
            --enable-gpl            \
            --enable-version3      \
            --enable-openssl        \
            --enable-libfreetype    \
            --enable-libfontconfig  \
            --enable-libharfbuzz    \
            --enable-libfribidi     \
            --enable-libass         \
            --enable-libdav1d       \
            --enable-libaom         \
            --enable-libopus        \
            --enable-libvmaf        \
            --enable-libvpx         \
            --enable-libfdk-aac     \
            --enable-libsvtav1      \
            --enable-libx264        \
            --enable-libx265        \
            --enable-nonfree        \
            --disable-doc           \
            --disable-debug         \
            --disable-x86asm

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
