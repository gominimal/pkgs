#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Mesa requires python packaging and mako modules
pip3 install packaging mako pyyaml 2>/dev/null || pip install packaging mako pyyaml 2>/dev/null || true

mkdir build && cd build
meson setup --prefix=/usr --buildtype=release \
  -Dplatforms=x11 \
  -Dgallium-drivers=softpipe \
  -Dvulkan-drivers='' \
  -Dglx=disabled \
  -Degl=enabled \
  -Dgbm=enabled \
  -Dllvm=disabled \
  ..
ninja
DESTDIR="$OUTPUT_DIR" ninja install
