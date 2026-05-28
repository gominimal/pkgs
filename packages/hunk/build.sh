#!/bin/bash
set -euo pipefail

mkdir -p .bun-tmp .bun-install
export BUN_TMPDIR="$PWD/.bun-tmp"
export BUN_INSTALL="$PWD/.bun-install"

bun install --frozen-lockfile --ignore-scripts

bun build --compile ./src/main.tsx --outfile hunk

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 hunk "$OUTPUT_DIR/usr/bin/hunk"
ln -s hunk "$OUTPUT_DIR/usr/bin/hunkdiff"
