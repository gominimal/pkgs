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
  -Dman-pages=disabled \
  -Ddtrace=false \
  -Dsystemtap=false \
  -Dgtk_doc=false \
  -Dtests=false \
  ..
ninja
DESTDIR="$OUTPUT_DIR" ninja install

# Regression test for CVE-2026-16118, using the just-installed `gio`. The bug
# is observable, not only a memory error. The unpatched swap loop writes word
# i to byte offset i*word_size, so for a 4-byte `~2` value it swaps the first
# word, writes the second word out of bounds, and leaves bytes 2..3 unswapped.
# A magic rule `>0=ABCD~2` must therefore become the byte string "BADC" on
# little-endian hosts and match a file that starts with "BADC". Unpatched it
# stays "BACD", the file goes unrecognised, and this test fails. On big-endian
# hosts no swap happens at all, so the test would not be meaningful there.
if [ "$(printf '\001\000' | od -An -tu2 | tr -d ' ')" = "1" ]; then
  t="$(pwd)/cve-2026-16118"
  mkdir -p "$t/home/mime" "$t/sys"
  printf 'MIME-Magic\000\n[50:application/x-cve-2026-16118]\n>0=\000\004ABCD~2\n' \
    > "$t/home/mime/magic"
  printf 'BADC\001\002\003\004\377\376' > "$t/probe"
  got=$(XDG_DATA_HOME="$t/home" XDG_DATA_DIRS="$t/sys" \
        LD_LIBRARY_PATH="$OUTPUT_DIR/usr/lib" \
        "$OUTPUT_DIR/usr/bin/gio" info -a standard::content-type "$t/probe" \
        | sed -n 's/^ *standard::content-type: //p')
  echo "CVE-2026-16118 probe content type: '$got'"
  [ "$got" = "application/x-cve-2026-16118" ]
  rm -rf "$t"
fi
