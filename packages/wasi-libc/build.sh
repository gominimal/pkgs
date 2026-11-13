#!/bin/sh
set -ex

# clang 21's default wasm CPU turns on bulk-memory, multivalue, reference-types,
# nontrapping-fptoint and call-indirect-overlong; clang 17's enabled only
# sign-ext and mutable-globals. This pins the clang 17 feature set.
WASM_FEATURES="-mcpu=mvp -mmutable-globals"

# clang 21 puts -Wunterminated-string-initialization in -Wextra; musl's
# vfprintf.c xdigits[16] trips it under the Makefile's -Werror.
NOWERR="-Wno-error=unterminated-string-initialization"

# clang 23 deprecates the bare `wasm32-wasi` triple (-Wdeprecated, an error
# under the Makefile's -Werror) in favour of `wasm32-wasip1`. The wasi-sdk-21
# Makefile hard-codes wasm32-wasi (so do wasi-sdk-22..26's), and a command-line
# TARGET_TRIPLE overrides it. It also names the sysroot's lib dir, which is
# where clang looks for a wasm32-wasip1 link (lib/<triple>). check-symbols'
# expected/<triple> dir would not match, but `finish` is not built (below).
TRIPLE=wasm32-wasip1

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
  TARGET_TRIPLE="$TRIPLE" \
  BULK_MEMORY_SOURCES= \
  EXTRA_CFLAGS="-O2 -DNDEBUG $WASM_FEATURES $NOWERR -ffile-prefix-map=$PWD=/builddir" \
  startup_files libc

# The placeholder archives `finish` creates.
for name in m rt pthread crypt util xnet resolv; do
  llvm-ar crs "sysroot/lib/$TRIPLE/lib${name}.a"
done

# Nothing may land under the deprecated triple: every consumer passes
# --target=wasm32-wasip1 and clang searches lib/wasm32-wasip1 only.
test -f "sysroot/lib/$TRIPLE/libc.a"
test ! -e sysroot/lib/wasm32-wasi

mkdir -p "$OUTPUT_DIR/usr/lib/wasi"
cp -r sysroot/include sysroot/lib "$OUTPUT_DIR/usr/lib/wasi/"

mkdir -p "$OUTPUT_DIR/usr/share/licenses/wasi-libc"
cp LICENSE LICENSE-APACHE LICENSE-APACHE-LLVM LICENSE-MIT \
  "$OUTPUT_DIR/usr/share/licenses/wasi-libc/"
# The bundled third-party notices: cloudlibc (BSD-2-Clause) and musl (MIT).
# Renamed on install because cloudlibc's file is also called LICENSE.
cp libc-bottom-half/cloudlibc/LICENSE "$OUTPUT_DIR/usr/share/licenses/wasi-libc/LICENSE-cloudlibc"
cp libc-top-half/musl/COPYRIGHT "$OUTPUT_DIR/usr/share/licenses/wasi-libc/COPYRIGHT-musl"
