#!/bin/sh
set -e

# Install @capysc/cli (the `capy` CLI) into the package output prefix.
# Outputs are harvested from $OUTPUT_DIR (see build.ncl `outputs`).
PREFIX="$OUTPUT_DIR/usr"
mkdir -p "$PREFIX"

# Keep npm's cache inside the build sandbox (no writable $HOME).
export npm_config_cache="$(pwd)/.npm-cache"

npm install \
  --global \
  --prefix "$PREFIX" \
  --no-audit --no-fund \
  "@capysc/cli@${MINIMAL_ARG_VERSION}"
