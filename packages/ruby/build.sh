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

# GCC 14 turned several long-tolerated warnings into errors, so native
# extensions of older gems that compile fine under GCC 13 or clang now fail
# here (scout_apm 5.x: incompatible-pointer-types). Downgrade exactly those
# back to warnings for gem extension builds: mkmf takes its flags from the
# installed rbconfig, not from $CFLAGS, and Ruby itself is already built.
# (CONFIG["CFLAGS"], not "warnflags": configuring with our own CFLAGS above
# drops $(cflags), and with it $(warnflags), from extension Makefiles.)
rbconfig=$(find "$OUTPUT_DIR/usr/lib/ruby" -name rbconfig.rb | head -1)
[ -n "$rbconfig" ] || { echo "rbconfig.rb not found under $OUTPUT_DIR/usr/lib/ruby" >&2; exit 1; }
gcc14_errors="-Wno-error=incompatible-pointer-types -Wno-error=int-conversion -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=return-mismatch -Wno-error=declaration-missing-parameter-type"
sed -i "s|^\(  CONFIG\[\"CFLAGS\"\] = \"[^\"]*\)\"|\1 $gcc14_errors\"|" "$rbconfig"
grep -q 'CONFIG\["CFLAGS"\] = ".*-Wno-error=incompatible-pointer-types' "$rbconfig" \
  || { echo "failed to extend CFLAGS in $rbconfig" >&2; exit 1; }
