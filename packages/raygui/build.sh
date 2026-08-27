#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac

CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
LDFLAGS="-Wl,--build-id=none"

# raygui ships as a single header; the library is that header compiled once with
# RAYGUI_IMPLEMENTATION. -x c because the file is named .h.
gcc -c -x c src/raygui.h -o raygui.o -DRAYGUI_IMPLEMENTATION -fPIC $CFLAGS

mkdir -p "$OUTPUT_DIR/usr/lib" "$OUTPUT_DIR/usr/include"

ar -D rcs "$OUTPUT_DIR/usr/lib/libraygui.a" raygui.o

# raygui has no versioned-soname convention upstream, so the SONAME matches the
# plain filename the Odin bindings and everyone else link against.
gcc -shared -Wl,-soname,libraygui.so -o "$OUTPUT_DIR/usr/lib/libraygui.so" \
  raygui.o $LDFLAGS -lraylib -lm

install -m 0644 src/raygui.h "$OUTPUT_DIR/usr/include/raygui.h"

# --- wasm -------------------------------------------------------------------
# Same single header, compiled for wasm32 against raylib's headers. emcc wants a
# writable cache even when every entry is present, and the installed one is
# read-only.
export EM_CACHE="$(pwd)/.emcache"
cp -r /usr/share/emscripten/cache "$EM_CACHE"

# emcc searches emscripten's own sysroot, not /usr/include, so raylib.h has to
# be put where raygui.h's quoted include will find it -- beside the source.
# Copying beats -I/usr/include, which would also shadow musl's stdio.h and
# stdlib.h with the native glibc ones.
cp /usr/include/raylib.h src/

emcc -c -x c src/raygui.h -o raygui_wasm.o -DRAYGUI_IMPLEMENTATION \
  -Os -ffile-prefix-map="$(pwd)"=/builddir
mkdir -p "$OUTPUT_DIR/usr/lib/emscripten"
emar rcs "$OUTPUT_DIR/usr/lib/emscripten/libraygui.a" raygui_wasm.o

rm -rf "$EM_CACHE"
