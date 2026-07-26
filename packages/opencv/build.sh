#!/bin/sh
set -e

# Create build directory
mkdir -p build && cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Configure.
#
# WITH_OPENJPEG=ON + BUILD_OPENJPEG=OFF links the system openjpeg (our
# 2.5.4 package) instead of compiling the bundled 3rdparty/openjpeg copy.
# The bundled copy is what OSS-Fuzz flagged as OSV-2023-444 (heap-overflow
# in opj_jp2_apply_pclr); the system lib carries the upstream fix
# (OpenJPEG PR #1441, shipped in 2.5.1+), so this removes the vulnerable
# code rather than asserting the vendored copy is patched.
cmake \
        -DCMAKE_INSTALL_PREFIX=/usr         \
        -DOPENCV_GENERATE_PKGCONFIG=ON      \
        -DOPENCV_LIB_INSTALL_PATH=/usr/lib  \
        -DWITH_OPENJPEG=ON                  \
        -DBUILD_OPENJPEG=OFF                \
        ../opencv-$MINIMAL_ARG_VERSION

# Build
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
