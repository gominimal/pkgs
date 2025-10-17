#!/bin/sh
set -e

# Create build directory
mkdir -p build && cd build

# Configure
cmake \
        -DCMAKE_INSTALL_PREFIX=/usr         \
        -DOPENCV_GENERATE_PKGCONFIG=ON      \
        -DOPENCV_LIB_INSTALL_PATH=/usr/lib  \
        ../opencv-$MINIMAL_ARG_VERSION

# Build
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
