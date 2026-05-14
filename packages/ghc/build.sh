#!/bin/bash
set -euo pipefail

# Extract source tarball manually (avoids staging issues with hardlink entries in tarball)
tar -xof ghc-%{version}-src.tar.xz

# cd into extracted source directory
cd ghc-%{version}

# Remove nofib benchmark suite (contains hardlink entries that can cause staging issues)
rm -rf nofib

# Configure GHC (configure script is included in the source tarball)
./configure --prefix=/usr

# Build using hadrian (default for GHC 9.x)
./hadrian/build -j$(nproc) --flavour=quickest --disable-split-objs --enable-shared

# Install to output directory
./hadrian/build install --root=$OUTPUT_DIR
