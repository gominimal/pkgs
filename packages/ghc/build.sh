#!/bin/sh
set -euo pipefail

# Generate configure script
./boot

# Configure GHC
./configure --prefix=/usr \
            --disable-split-objs \
            --enable-shared \

# Build using hadrian (default for GHC 9.x)
./hadrian/build -j$(nproc) --flavour=quickest

# Install to output directory
./hadrian/build install --root=$OUTPUT_DIR
