#!/bin/sh
set -euo pipefail

# Extract source tarball manually to avoid RES staging symlinks in nofib
# (the nofib benchmark suite uses symlinks that break remote execution staging)
tar -xof ghc-$MINIMAL_ARG_VERSION-src.tar.xz
cd ghc-$MINIMAL_ARG_VERSION

# Remove nofib benchmark suite before any build steps
rm -rf nofib

# Configure GHC (configure script is included in the source tarball)
./configure --prefix=/usr

# Build using hadrian (default for GHC 9.x)
./hadrian/build -j$(nproc) --flavour=quickest --disable-split-objs --enable-shared

# Install to output directory
./hadrian/build install --root=$OUTPUT_DIR
