#!/bin/sh
set -ex

install -d "$OUTPUT_DIR/usr/bin"
curl -sfS https://dotenvx.sh/install.sh \
  | sh -s -- \
    --os=linux \
    --arch="$MINIMAL_ARG_ARCH" \
    --directory="$OUTPUT_DIR/usr/bin" \
    --version="$MINIMAL_ARG_VERSION" \
    --force
