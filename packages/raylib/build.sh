#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac

# raylib's Makefile owns -O and the platform defines, so determinism flags ride
# in through its CUSTOM_* hooks rather than CFLAGS/LDFLAGS. rglfw.c uses
# assert(), which bakes __FILE__ into the objects without -ffile-prefix-map.
CUSTOM_CFLAGS="$MARCH -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"

# PLATFORM_DESKTOP resolves to PLATFORM_DESKTOP_GLFW, the X11 backend the Odin
# bindings (and every other consumer) expect. `ar -D` for deterministic archives.
build() { # $1 = STATIC | SHARED, $2 = extra LDFLAGS
  make -C src clean
  make -C src -j"$(nproc)" \
    PLATFORM=PLATFORM_DESKTOP \
    RAYLIB_LIBTYPE="$1" \
    RAYLIB_BUILD_MODE=RELEASE \
    CC=gcc \
    AR="ar -D" \
    CUSTOM_CFLAGS="$CUSTOM_CFLAGS" \
    CUSTOM_LDFLAGS="-Wl,--build-id=none $2"
}

mkdir -p "$OUTPUT_DIR/usr/lib" "$OUTPUT_DIR/usr/include"

build STATIC
install -m 0644 src/libraylib.a "$OUTPUT_DIR/usr/lib/libraylib.a"

# Upstream links the shared library without a SONAME, so anything linking
# -lraylib records a bare "libraylib.so". Set the versioned one instead.
build SHARED -Wl,-soname,libraylib.so.600
install -m 0755 src/libraylib.so.6.0.0 "$OUTPUT_DIR/usr/lib/libraylib.so.6.0.0"
ln -sf libraylib.so.6.0.0 "$OUTPUT_DIR/usr/lib/libraylib.so.600"
ln -sf libraylib.so.600 "$OUTPUT_DIR/usr/lib/libraylib.so"

install -m 0644 src/raylib.h src/raymath.h src/rlgl.h "$OUTPUT_DIR/usr/include/"

# --- wasm -------------------------------------------------------------------
# PLATFORM_WEB switches the Makefile to CC=emcc / AR=emar and to the GLES2
# backend emscripten maps onto WebGL. No -march here: the target is wasm32.
# emcc wants to write to its cache even when every entry is already present, and
# the installed cache is read-only, so it gets a writable copy for this build.
export EM_CACHE="$(pwd)/.emcache"
cp -r /usr/share/emscripten/cache "$EM_CACHE"

make -C src clean
make -C src -j"$(nproc)" \
  PLATFORM=PLATFORM_WEB \
  RAYLIB_BUILD_MODE=RELEASE \
  CUSTOM_CFLAGS="-ffile-prefix-map=$(pwd)=/builddir"

install -D -m 0644 src/libraylib.web.a "$OUTPUT_DIR/usr/lib/emscripten/libraylib.web.a"

rm -rf "$EM_CACHE"
