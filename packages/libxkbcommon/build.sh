#!/bin/sh
set -e

mkdir build &&
cd    build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# 1.13.2 added the "config extensions" lookup dirs, and tools/info.c references
# DFLT_XKB_CONFIG_{UN,}VERSIONED_EXTENSIONS_PATH unconditionally — but meson only
# defines those macros when the paths are non-empty, which needs either these
# options or an xkeyboard-config pkg-config dep (which we don't ship). Unlike the
# main config root, the extension paths have no legacy fallback, so set them
# explicitly to upstream's default derivation. Fixes an undeclared-identifier
# build break on the version bump.
meson setup --prefix=/usr --buildtype=release -Denable-x11=true -Denable-wayland=false -Denable-docs=false \
  -Dxkb-config-unversioned-extensions-path=/usr/share/xkeyboard-config.d \
  -Dxkb-config-versioned-extensions-path=/usr/share/X11/xkb.d ..
ninja

DESTDIR="$OUTPUT_DIR" ninja install
