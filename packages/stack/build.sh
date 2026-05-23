#!/bin/bash
set -euo pipefail

cabal update
cabal build

# Install stack binary
mkdir -p "$OUTPUT_DIR"/usr/bin
cp -v "$(cabal list-bin stack)" "$OUTPUT_DIR"/usr/bin/

# Install man pages
mkdir -p "$OUTPUT_DIR"/usr/share/man/man1
cp -v doc/man/stack.1 "$OUTPUT_DIR"/usr/share/man/man1/ 2>/dev/null || true

# Install documentation
mkdir -p "$OUTPUT_DIR"/usr/share/doc/stack
cp -v doc/README.md "$OUTPUT_DIR"/usr/share/doc/stack/ 2>/dev/null || true
