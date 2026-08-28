#!/bin/bash
set -euo pipefail

tar -xof "ruby-$MINIMAL_ARG_VERSION.tar.gz"
cd "ruby-$MINIMAL_ARG_VERSION"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
  --enable-shared \
  --disable-install-doc \
  --disable-install-rdoc

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install

# gem auto-falls back to user installs (the store is read-only), but its
# binstubs then land in ~/.local/share/gem/ruby/<v>/bin — off PATH. RubyGems'
# system-wide config lives inside the package at /usr/etc/gemrc, so ship one
# redirecting binstubs to ~/.local/bin (on the session PATH); RubyGems expands
# the ~, applies the flag to install and uninstall symmetrically, and user
# config (GEMRC, ~/.gemrc, CLI flags) still wins. See gominimal/inbox#584.
mkdir -p "$OUTPUT_DIR/usr/etc"
printf 'gem: --bindir ~/.local/bin\n' > "$OUTPUT_DIR/usr/etc/gemrc"
