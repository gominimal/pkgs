#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# meson.build needs the python modules packaging, mako and yaml. They come from
# py-packaging, py-mako and py-pyyaml in build_deps: nothing is fetched here.
python3 -c 'import packaging, mako, yaml'

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
