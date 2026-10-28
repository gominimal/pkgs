#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
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
            --enable-libsvtav1      \
            --enable-libx264        \
            --enable-libx265        \
            --disable-doc           \
            --disable-debug         \
            --disable-x86asm

# Fail closed if the build would not be redistributable. configure writes the
# license it derived from the flags into config.h; "nonfree and
# unredistributable" (libfdk-aac) must never ship again (pkgs#1110).
echo "ffmpeg license: $(sed -n 's/^#define FFMPEG_LICENSE "\(.*\)"$/\1/p' config.h)"
grep -q '^#define FFMPEG_LICENSE "GPL version 3 or later"$' config.h || {
  echo "ffmpeg: configure did not report GPL version 3 or later; refusing to build" >&2
  exit 1
}

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
