#!/bin/sh
set -e

tar -xof ncurses-6.5-20250830.tgz
cd ncurses-6.5-20250830

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr          \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --with-cxx-shared       \
            --enable-pc-files       \
            --enable-symlinks       \
            --with-pkg-config-libdir=/usr/lib/pkgconfig

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install

# Ghostty terminal sets TERM=xterm-ghostty but ncurses upstream only ships
# a 'ghostty' entry. Add xterm-ghostty as a symlink so programs find a match.
mkdir -p "$OUTPUT_DIR/usr/share/terminfo/x"
ln -sf ../g/ghostty "$OUTPUT_DIR/usr/share/terminfo/x/xterm-ghostty"
