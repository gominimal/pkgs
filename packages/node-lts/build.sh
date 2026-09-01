#!/bin/sh
set -e

export CC=gcc

tar -xof "node-v${MINIMAL_ARG_VERSION}.tar.gz"
cd "node-v${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
    --with-intl=system-icu --shared-openssl --shared-zlib --shared-zstd --shared-sqlite --shared-libuv \
    --shared-nghttp2 --shared-nghttp3 --shared-ngtcp2 --shared-gtest --shared-cares
    # Note: --shared-lief is omitted; that configure option was not added until Node.js v25.
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install

# npm's compiled-in global prefix is /usr, which is the read-only package
# store at session time, so every `npm i -g` fails with ENOENT. Ship a
# builtin npmrc (npm's lowest-precedence config source, overridable by any
# user config) pointing globals at ~/.local, whose bin/ is already on the
# session PATH. See gominimal/inbox#559.
printf 'prefix=~/.local\n' > "$OUTPUT_DIR/usr/lib/node_modules/npm/npmrc"

# Upstream node 24.19.0 bundles npm 11.17.0 with a mis-nested dependency that
# breaks EVERY `npm install` (global or local, prefix or not):
#
#   npm/node_modules/minipass-flush/index.js does
#       const { Minipass } = require('minipass')
#   i.e. the minipass 7.x NAMED export (its package.json asks for ^7.1.3), but
#   upstream also ships minipass-flush/node_modules/minipass@3.3.6, which
#   exports the class as the DEFAULT and has no `.Minipass` property. The
#   nested copy shadows the correct hoisted minipass@7.1.3, so `Minipass` is
#   undefined and `class Flush extends undefined` throws
#   "Class extends value undefined is not a constructor or null".
#
# Worst part: with `--prefix` on the command line npm dies during config
# resolution, BEFORE it can print an error — stderr contains nothing but a
# pointer to a debug log that is itself empty of errors. That is what made
# gominimal/pkgs#665 look like a network fault for a day.
#
# Removing the shadowing copy lets minipass-flush resolve the hoisted 7.1.3.
# Verified: with it present `npm install` exits 1; removing this one directory
# makes the identical command succeed.
#
# This is a workaround for an upstream defect — DELETE IT once node-lts ships
# an npm whose tree is self-consistent. The `npm_install_works` test below is
# what proves whether it is still needed; it fails loudly either way, so this
# cannot rot into a carried no-op.
NPM_NM="$OUTPUT_DIR/usr/lib/node_modules/npm/node_modules"
if [ -d "$NPM_NM/minipass-flush/node_modules/minipass" ]; then
  if grep -q 'const { Minipass } = require' "$NPM_NM/minipass-flush/index.js"; then
    rm -rf "$NPM_NM/minipass-flush/node_modules/minipass"
  else
    echo "ERROR: minipass-flush no longer uses the 7.x named import — upstream" >&2
    echo "       changed shape; re-check whether this workaround is still right." >&2
    exit 1
  fi
fi
