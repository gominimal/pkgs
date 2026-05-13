#!/bin/sh
set -ex

# Build stack from source using cabal
cabal build

# Install stack binary
mkdir -p "$OUTPUT_DIR"/usr/bin
cp -v dist-newstyle/build/*/x86_64-linux/stack/*/build/stack "$OUTPUT_DIR"/usr/bin/ 2>/dev/null || \
cp -v dist-newstyle/build/*/aarch64-linux/stack/*/build/stack "$OUTPUT_DIR"/usr/bin/ 2>/dev/null || \
cp -v dist-newstyle/build/*/*/stack/*/build/stack "$OUTPUT_DIR"/usr/bin/

# Install man pages
mkdir -p "$OUTPUT_DIR"/usr/share/man/man1
cp -v doc/man/stack.1 "$OUTPUT_DIR"/usr/share/man/man1/ 2>/dev/null || true

# Install documentation
mkdir -p "$OUTPUT_DIR"/usr/share/doc/stack
cp -v doc/README.md "$OUTPUT_DIR"/usr/share/doc/stack/ 2>/dev/null || true
