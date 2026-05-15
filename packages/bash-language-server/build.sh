#!/bin/sh
set -ex

# Hermetic build path: when /npm-cache exists (mounted by a SLSA-grade
# builder that has pre-staged the populated npm cacache from a sha-
# verified npm_cache tarball), install bash-language-server offline
# from the cache. Otherwise fall back to the normal online install
# for dev iteration.
if [ -d /npm-cache ]; then
    npm install -g \
        --offline \
        --cache=/npm-cache \
        --prefix="$OUTPUT_DIR/usr" \
        bash-language-server@$MINIMAL_ARG_VERSION
else
    npm install -g --prefix=$OUTPUT_DIR/usr bash-language-server@$MINIMAL_ARG_VERSION
fi
