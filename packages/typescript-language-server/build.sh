#!/bin/sh
set -ex

# Pin typescript. Installing it unpinned pulled TypeScript 7.0.2 (the native
# rewrite), which DROPPED the `tsserver` bin entry (its bin is now just `tsc`),
# so the `usr/bin/tsserver` output glob matched nothing and the build failed.
# 5.9.3 is the latest 5.x, still ships tsserver, and is what
# typescript-language-server 4.3.3 targets. Pinning also makes this
# internet-fetching build deterministic instead of tracking npm's `latest`.
#
# Install into a package-PRIVATE prefix (NOT the shared usr/lib/node_modules, which
# node/node-lts own); expose thin symlinks on PATH. Both npm packages land in the
# one prefix, so all three bins (typescript-language-server, tsc, tsserver) get a
# launcher. The inner `#!/usr/bin/env node` shebang is served by coreutils+node.
TSLS_PREFIX="$OUTPUT_DIR/usr/libexec/typescript-language-server"

# Hermetic build path: when /npm-cache exists (mounted by a SLSA-grade
# builder that has pre-staged the populated npm cacache from a sha-
# verified npm_cache tarball), install offline from the cache. Otherwise
# fall back to the normal online install for dev iteration. Same pattern
# as bash-language-server.
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
        --prefix="$TSLS_PREFIX" \
        typescript-language-server@$MINIMAL_ARG_VERSION \
        typescript@5.9.3
else
    npm install -g --prefix="$TSLS_PREFIX" \
        typescript-language-server@$MINIMAL_ARG_VERSION \
        typescript@5.9.3
fi

mkdir -p "$OUTPUT_DIR/usr/bin"
for _bin in "$TSLS_PREFIX/bin/"*; do
  [ -e "$_bin" ] || continue
  _tool=${_bin##*/}
  ln -s "../libexec/typescript-language-server/bin/$_tool" "$OUTPUT_DIR/usr/bin/$_tool"
done
