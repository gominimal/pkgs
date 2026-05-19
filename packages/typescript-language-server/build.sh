#!/bin/sh
set -ex

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
        --prefix="$OUTPUT_DIR/usr" \
        typescript-language-server@$MINIMAL_ARG_VERSION \
        typescript
else
    npm install -g --prefix=$OUTPUT_DIR/usr \
        typescript-language-server@$MINIMAL_ARG_VERSION \
        typescript
fi
