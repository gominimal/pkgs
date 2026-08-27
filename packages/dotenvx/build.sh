#!/bin/sh
set -ex

# The release tarball is flat: a single `dotenvx` binary at the top level, so
# there is nothing to strip_prefix and nothing to compile — just install it.
install -d "$OUTPUT_DIR/usr/bin"
install -m 755 dotenvx "$OUTPUT_DIR/usr/bin/dotenvx"
