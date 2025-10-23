#!/bin/sh
set -e

mkdir build &&
cd    build

cmake -D CMAKE_INSTALL_PREFIX=/usr      \
      -D CMAKE_INSTALL_LIBDIR=/usr/lib  \
      -D CMAKE_BUILD_TYPE=Release       \
      -D ABSL_PROPAGATE_CXX_STD=ON      \
      -D BUILD_SHARED_LIBS=ON           \
      -G Ninja ..
ninja

DESTDIR="$OUTPUT_DIR" ninja install
