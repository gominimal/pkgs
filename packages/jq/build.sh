#!/bin/sh
set -e

ls -lah
cd "jq-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc
export CXXFLAGS="${CFLAGS}"

# The oniguruma package, not jq's bundled copy: the bundled one installs
# libonig, oniguruma.h and oniguruma.pc at the paths oniguruma ships, a file
# conflict in any box that has both (bat and delta depend on oniguruma).
./configure --prefix=/usr                   \
            --with-oniguruma=/usr

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
