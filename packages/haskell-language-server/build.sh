#!/bin/bash
set -euo pipefail

# The source tarball is already extracted with strip_prefix, so we're in the source root

# Build HLS for the GHC version available in the sandbox
export GHC="$(command -v ghc)"
export CABAL="$(command -v cabal)"

# Update cabal package index
# Pin cabal index-state to the release date of haskell-language-server 2.14.0.0
# to ensure build reproducibility and prevent dependency version drift.
echo "index-state: 2026-04-28T00:00:00Z" > cabal.project.local

cabal update

# Build HLS with the available GHC version
cabal build \
  --ghc-options="-j$(nproc)" \
  exe:haskell-language-server

# Install to OUTPUT_DIR
mkdir -p "$OUTPUT_DIR"/usr/bin
mkdir -p "$OUTPUT_DIR"/usr/lib

# Find and copy the built binary from cabal's build directory
HLS_BIN=$(cabal list-bin exe:haskell-language-server)
cp "$HLS_BIN" "$OUTPUT_DIR"/usr/bin/

# Copy all shared Haskell libraries the binary depends on
for lib in $(ldd "$HLS_BIN" | grep '\.so' | awk '{print $3}'); do
  if [ -n "$lib" ] && [ -f "$lib" ]; then
    cp "$lib" "$OUTPUT_DIR"/usr/lib/
  fi
done
