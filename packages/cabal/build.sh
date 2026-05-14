#!/bin/bash
set -euo pipefail

# Build cabal from source using the bundled GHC
cabal build

# Install cabal binary
mkdir -p "$OUTPUT_DIR"/usr/bin
cp -v dist-newstyle/build/*/x86_64-linux/cabal-install-*/build/cabal/cabal "$OUTPUT_DIR"/usr/bin/ 2>/dev/null || \
cp -v dist-newstyle/build/*/aarch64-linux/cabal-install-*/build/cabal/cabal "$OUTPUT_DIR"/usr/bin/ 2>/dev/null || \
cp -v dist-newstyle/build/*/*/cabal-install-*/build/cabal/cabal "$OUTPUT_DIR"/usr/bin/

# Install man pages
mkdir -p "$OUTPUT_DIR"/usr/share/man/man1
cp -v doc/man/cabal.1 "$OUTPUT_DIR"/usr/share/man/man1/ 2>/dev/null || true

# Install documentation
mkdir -p "$OUTPUT_DIR"/usr/share/doc/cabal
cp -v README.md "$OUTPUT_DIR"/usr/share/doc/cabal/ 2>/dev/null || true
