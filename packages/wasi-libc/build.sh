#!/bin/sh
set -ex

# clang 21's default wasm CPU turns on bulk-memory, multivalue, reference-types,
# nontrapping-fptoint and call-indirect-overlong; clang 17's enabled only
# sign-ext and mutable-globals. This pins the clang 17 feature set.
WASM_FEATURES="-mcpu=mvp -mmutable-globals"

# clang 21 puts -Wunterminated-string-initialization in -Wextra; musl's
# vfprintf.c xdigits[16] trips it under the Makefile's -Werror.
NOWERR="-Wno-error=unterminated-string-initialization"

# Empty BULK_MEMORY_SOURCES compiles musl's memcpy/memmove/memset without the
# per-file -mbulk-memory the Makefile adds.
#
# `finish` is not built: it depends on check-symbols, whose predefined-macro
# list stops at clang 18, so the steps it runs after `libc` are done below.
make -j"$(nproc)" \
  CC=clang \
  AR=llvm-ar \
  NM=llvm-nm \
  SYSROOT="$PWD/sysroot" \
  THREAD_MODEL=single \
  BULK_MEMORY_SOURCES= \
  EXTRA_CFLAGS="-O2 -DNDEBUG $WASM_FEATURES $NOWERR -ffile-prefix-map=$PWD=/builddir" \
  startup_files libc

# The placeholder archives `finish` creates.
for name in m rt pthread crypt util xnet resolv; do
  llvm-ar crs "sysroot/lib/wasm32-wasi/lib${name}.a"
done

mkdir -p "$OUTPUT_DIR/usr/lib/wasi"
cp -r sysroot/include sysroot/lib "$OUTPUT_DIR/usr/lib/wasi/"

mkdir -p "$OUTPUT_DIR/usr/share/licenses/wasi-libc"
cp LICENSE LICENSE-APACHE LICENSE-APACHE-LLVM LICENSE-MIT \
  "$OUTPUT_DIR/usr/share/licenses/wasi-libc/"
