#!/bin/sh
set -ex

# Install into a package-PRIVATE prefix (NOT the shared usr/lib/node_modules, which
# the node/node-lts runtime owns) so the tool can't collide with it; expose thin
# symlinks on PATH. The inner `#!/usr/bin/env node` shebang is served by
# coreutils(env)+node, so no shell is needed. (twitchyliquid64 review on #370.)
#
# Hermetic build path: when /npm-cache exists (mounted by a SLSA-grade
# builder that has pre-staged the populated npm cacache from a sha-
# verified npm_cache tarball), install bash-language-server offline
# from the cache. Otherwise fall back to the normal online install
# for dev iteration.
#
# /npm-cache is mounted READ-ONLY via extra_rootfs. npm's cacache
# library writes bookkeeping (locks, logs, atomic-rename temp files)
# on every operation including --offline reads, so a read-only cache
# fails silently with ENOTCACHED. Copy to a writable scratch dir first.
if [ -d /npm-cache ]; then
    NPM_CACHE_RW=/tmp/npm-cache
    cp -r /npm-cache "$NPM_CACHE_RW"
    npm install -g \
        --offline \
        --cache="$NPM_CACHE_RW" \
        --prefix="$OUTPUT_DIR/usr/libexec/bash-language-server" \
        bash-language-server@$MINIMAL_ARG_VERSION
else
    npm install -g --prefix="$OUTPUT_DIR/usr/libexec/bash-language-server" bash-language-server@$MINIMAL_ARG_VERSION
fi

mkdir -p "$OUTPUT_DIR/usr/bin"
for _bin in "$OUTPUT_DIR/usr/libexec/bash-language-server/bin/"*; do
  [ -e "$_bin" ] || continue
  _tool=${_bin##*/}
  ln -s "../libexec/bash-language-server/bin/$_tool" "$OUTPUT_DIR/usr/bin/$_tool"
done
