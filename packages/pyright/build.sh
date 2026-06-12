#!/bin/sh
set -ex

# CS-builder offline path: orch stage npm populates /npm-cache with pyright
# + its deps; install from there with --offline. Outside CS (no /npm-cache),
# fall back to the online registry.
if [ -d /npm-cache ]; then
    # DIAGNOSTIC (#53): npm --offline returns ENOTCACHED on the pyright packument
    # even though the staged cache HAS it (verified: registry.npmjs.org/pyright is in
    # the tarball's index-v5). Settle empty-hydration-in-queue-mode vs npm cache-key
    # skew: show npm/node versions (the fetcher's staging npm may differ from this
    # source-built npm → different cacache keys), whether /npm-cache/_cacache is
    # actually populated at build time, and whether the packument key survives.
    echo "=[pyright-diag]= npm $(npm --version 2>&1) / node $(node --version 2>&1)"
    echo "=[pyright-diag]= /npm-cache top:"; ls -la /npm-cache 2>&1 | head
    echo "=[pyright-diag]= _cacache:"; ls -la /npm-cache/_cacache 2>&1 | head
    echo "=[pyright-diag]= index-v5 entries:"; find /npm-cache/_cacache/index-v5 -type f 2>/dev/null | wc -l
    echo "=[pyright-diag]= pyright packument key present?:"; grep -rl "registry.npmjs.org/pyright" /npm-cache/_cacache/index-v5/ 2>/dev/null | head -1
    npm install -g --offline --cache=/npm-cache \
        --prefix=$OUTPUT_DIR/usr pyright@$MINIMAL_ARG_VERSION
else
    npm install -g --prefix=$OUTPUT_DIR/usr pyright@$MINIMAL_ARG_VERSION
fi
