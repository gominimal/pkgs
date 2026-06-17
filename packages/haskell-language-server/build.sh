#!/bin/bash
set -euo pipefail

# The source tarball is already extracted with strip_prefix, so we're in the source root

# Build HLS for the GHC version available in the sandbox
export GHC="$(command -v ghc)"
export CABAL="$(command -v cabal)"

# Update cabal package index
cabal update

# Reproducibility: strip embedded build paths from GHC-produced object files and
# suppress the linker's random build-id. These are the Haskell analogues of
# -ffile-prefix-map and -Wl,--build-id=none for C (see AGENTS.md §Reproducibility).
# -optc flags reach the C compiler GHC invokes for C stubs / Cmm; -optl reaches ld.
GHC_REPRO_OPTS="-optc-ffile-prefix-map=$(pwd)=/builddir -optl-Wl,--build-id=none"

# Build HLS with the available GHC version
cabal build \
  --ghc-options="-j$(nproc) $GHC_REPRO_OPTS" \
  exe:haskell-language-server

# Install to OUTPUT_DIR
mkdir -p "$OUTPUT_DIR"/usr/bin
mkdir -p "$OUTPUT_DIR"/usr/lib

# Find and copy the built binary from cabal's build directory
HLS_BIN=$(cabal list-bin exe:haskell-language-server)
cp "$HLS_BIN" "$OUTPUT_DIR"/usr/bin/

# Strip the linker build-id from the installed binary (cabal may re-link without
# our -optl flag for the final exe depending on version; belt-and-suspenders).
strip --remove-section=.note.gnu.build-id "$OUTPUT_DIR"/usr/bin/haskell-language-server 2>/dev/null || true

# Copy all shared Haskell libraries the binary depends on
for lib in $(ldd "$HLS_BIN" | grep '\.so' | awk '{print $3}'); do
  if [ -n "$lib" ] && [ -f "$lib" ]; then
    cp "$lib" "$OUTPUT_DIR"/usr/lib/
  fi
done
