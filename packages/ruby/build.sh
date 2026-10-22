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
# The bundled gems' extension dirs keep their mkmf.log / gem_make.out: build logs that
# record gcc's random /tmp/ccXXXXXX.o names, so every build differs in them and nothing
# else (2026-10 prod-pair diff: 1 of 2926 files). Same cleanup as ruby-lsp.
find "$OUTPUT_DIR" \( -name mkmf.log -o -name gem_make.out \) -delete

# gem auto-falls back to user installs (the store is read-only), but its
# binstubs then land in ~/.local/share/gem/ruby/<v>/bin — off PATH. RubyGems'
# system-wide config lives inside the package at /usr/etc/gemrc, so ship one
# redirecting binstubs to ~/.local/bin (on the session PATH); RubyGems expands
# the ~, and user config (GEMRC, ~/.gemrc, CLI flags) still wins.
#
# Per-command keys rather than a `gem:` line: RubyGems merges config files key
# by key, so a user's own `gem: --no-document` would replace ours and silently
# drop the bindir. Only a user `install:`/`update:`/`uninstall:` line can do
# that now. uninstall carries it too so it removes the stubs install wrote.
#
# Bundler reads none of this: `bundle install` executables stay off PATH
# (out of scope here). See gominimal/inbox#584.
mkdir -p "$OUTPUT_DIR/usr/etc"
printf '%s\n' \
  'install: --bindir ~/.local/bin' \
  'update: --bindir ~/.local/bin' \
  'uninstall: --bindir ~/.local/bin' \
  > "$OUTPUT_DIR/usr/etc/gemrc"
