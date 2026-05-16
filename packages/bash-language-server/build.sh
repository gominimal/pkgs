#!/bin/sh
set -ex

# Hermetic build path: when /npm-cache exists (mounted by a SLSA-grade
# builder that has pre-staged the populated npm cacache from a sha-
# verified npm_cache tarball), install bash-language-server offline
# from the cache. Otherwise fall back to the normal online install
# for dev iteration.
if [ -d /npm-cache ]; then
    # Diagnostics: dump the cache state so we can debug ENOTCACHED
    # without needing CS sandbox access. Remove once the npm-cache
    # hydrate path is stable.
    echo "=== /npm-cache top-level ==="
    ls -la /npm-cache/ || echo "MISSING"
    echo "=== _cacache contents ==="
    ls -la /npm-cache/_cacache/ 2>&1 | head -20 || echo "NO _cacache"
    echo "=== index-v5 sample ==="
    ls /npm-cache/_cacache/index-v5/ 2>&1 | head -5 || echo "NO index-v5"
    echo "=== bash-language-server entry in index? ==="
    grep -lr "bash-language-server" /npm-cache/_cacache/index-v5/ 2>&1 | head -5 || echo "NOT FOUND in index"
    echo "=== content-v2 count ==="
    find /npm-cache/_cacache/content-v2 -type f 2>/dev/null | wc -l
    echo "=== npm version in sandbox ==="
    node --version
    npm --version
    echo "=== node config / npmrc state ==="
    npm config list 2>&1 | head -20
    echo "=== try install ==="

    npm install -g \
        --offline \
        --cache=/npm-cache \
        --prefix="$OUTPUT_DIR/usr" \
        bash-language-server@$MINIMAL_ARG_VERSION
else
    npm install -g --prefix=$OUTPUT_DIR/usr bash-language-server@$MINIMAL_ARG_VERSION
fi
