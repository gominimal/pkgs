#!/bin/bash
set -euo pipefail

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$CFLAGS"

# psmisc's configure looks for tgetent in -ltinfo/-lncurses/-ltermcap, but our
# ncurses is built wide-character-only (libncursesw). Expose it under the name
# configure probes for; the linked binaries still record libncursesw.so.6.
mkdir -p compat-lib
ln -sf /usr/lib/libncursesw.so compat-lib/libncurses.so
export LDFLAGS="-Wl,--build-id=none -L$(pwd)/compat-lib"

./configure --prefix=/usr \
            --docdir=/usr/share/doc/psmisc-$MINIMAL_ARG_VERSION

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
