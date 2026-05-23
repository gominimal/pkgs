#!/bin/bash
set -euo pipefail

# Fix the GHC version in cabal.project to match our installed GHC
sed -i "s/with-compiler: ghc-9.10.3/with-compiler: ghc-9.10.1/" cabal.project

# Remove cabal.config which pins exact dependency versions for GHC 9.10.3
rm -f cabal.config
sed -i "/^import: cabal\.config/d" cabal.project

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
