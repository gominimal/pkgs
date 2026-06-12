#!/bin/sh
set -ex

# CS-builder offline path: orch stage npm populates /npm-cache with pyright
# + its deps; install from there with --offline. Outside CS (no /npm-cache),
# fall back to the online registry.
if [ -d /npm-cache ]; then
    npm install -g --offline --cache=/npm-cache \
        --prefix=$OUTPUT_DIR/usr pyright@$MINIMAL_ARG_VERSION
else
    npm install -g --prefix=$OUTPUT_DIR/usr pyright@$MINIMAL_ARG_VERSION
fi
