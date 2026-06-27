#!/bin/bash
set -euo pipefail

# The source tarball is already extracted with strip_prefix, so we're in the source root

# Build HLS for the GHC version available in the sandbox
export GHC="$(command -v ghc)"
export CABAL="$(command -v cabal)"

# Update cabal package index
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

# Copy all shared Haskell libraries the binary depends on, skipping standard system runtime libraries
for lib in $(ldd "$HLS_BIN" | grep '\.so' | awk '{print $3}'); do
  if [ -n "$lib" ] && [ -f "$lib" ]; then
    lib_name=$(basename "$lib")
    case "$lib_name" in
      ld-linux*|libc.so*|libpthread.so*|libm.so*|libdl.so*|librt.so*|libutil.so*|libcrypt.so*|libgcc_s.so*|libresolv.so*|libnss_*|libnsl*|libstdc++*)
        echo "Skipping standard system runtime library: $lib_name"
        ;;
      *)
        cp "$lib" "$OUTPUT_DIR"/usr/lib/
        ;;
    esac
  fi
done
