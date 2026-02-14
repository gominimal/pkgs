#!/bin/sh
set -e

# Create build directory
mkdir -p build && cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

# Configure
cmake \
        -DCMAKE_INSTALL_PREFIX=/usr         \
        -DOPENCV_GENERATE_PKGCONFIG=ON      \
        -DOPENCV_LIB_INSTALL_PATH=/usr/lib  \
        ../opencv-$MINIMAL_ARG_VERSION

# Build
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
