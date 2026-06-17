#!/bin/sh
set -e

# `unzip` is a compatibility symlink to libarchive's `bsdunzip` (a runtime dep),
# the maintained successor to the EOL Info-ZIP unzip. The relative symlink
# resolves to /usr/bin/bsdunzip at runtime. bsdunzip is a drop-in for the flags
# our callers use (-o/-q/-d/-p).
mkdir -p "$OUTPUT_DIR/usr/bin"
ln -s bsdunzip "$OUTPUT_DIR/usr/bin/unzip"
