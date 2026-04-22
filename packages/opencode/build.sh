#!/bin/sh
set -e

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 opencode "$OUTPUT_DIR/usr/bin/opencode"
