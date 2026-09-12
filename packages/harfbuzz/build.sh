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

mkdir build && cd build
meson setup --prefix=/usr --buildtype=release \
  -Dfreetype=enabled \
  -Dglib=enabled \
  -Dcairo=disabled \
  -Dicu=disabled \
  -Dgobject=disabled \
  -Dintrospection=disabled \
  -Dtests=disabled \
  -Ddocs=disabled \
  ..

# Generate the GPU shader headers BEFORE the parallel compile.
#
# harfbuzz 14.x's meson build does not declare hb-gpu.cc's dependency on the
# generated hb-gpu-*-{glsl,msl,wgsl,hlsl}.hh headers (they are standalone
# CUSTOM_COMMAND targets), so ninja is free to compile hb-gpu.cc while
# gen-gpu-shader-artifacts.py is still writing them. On a workstation you
# essentially never lose that race; on the 48/144-core build fleet we lose it
# regularly. Observed 2026-08-22: hlsl+wgsl landed at .699585s and glsl+msl at
# .699829s, and the compile failed on exactly glsl and msl -- the two written
# last -- with "'hb_gpu_fragment_glsl' was not declared in this scope".
#
# Building the headers as an explicit first pass makes the ordering a fact
# rather than a scheduling accident, and costs a second. Lowering -j would
# only make the race rarer, not impossible. Drop this once harfbuzz declares
# the dependency upstream.
shader_hh=$(ninja -t targets all | grep -oE '^src/hb-gpu-[a-z0-9-]+\.hh' | sort -u)
[ -n "$shader_hh" ] && ninja $shader_hh

ninja

DESTDIR="$OUTPUT_DIR" ninja install
