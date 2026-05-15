#!/bin/bash
set -euo pipefail

# Extract source tarball manually (avoids staging issues with hardlink entries in tarball)
tar -xof "ghc-${MINIMAL_ARG_VERSION}-src.tar.xz"

# cd into extracted source directory
cd "ghc-${MINIMAL_ARG_VERSION}"

# Remove nofib benchmark suite (contains hardlink entries that can cause staging issues)
rm -rf nofib

# Configure GHC (configure script is included in the source tarball)
./configure --prefix=/usr

# Build using hadrian (default for GHC 9.x)
./hadrian/build -j$(nproc) --flavour=quickest

# Install to output directory
./hadrian/build install --root=$OUTPUT_DIR
