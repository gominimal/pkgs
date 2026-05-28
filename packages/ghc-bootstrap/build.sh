#!/bin/bash
set -euo pipefail

BOOTSTRAP_ARCH="$(uname -m)"
case "$BOOTSTRAP_ARCH" in
  x86_64)
    BOOTSTRAP_TAR="ghc-${MINIMAL_ARG_VERSION}-x86_64-deb11-linux.tar.xz"
    ;;
  aarch64)
    BOOTSTRAP_TAR="ghc-${MINIMAL_ARG_VERSION}-aarch64-deb10-linux.tar.xz"
    ;;
  *)
    echo "Unsupported architecture: $BOOTSTRAP_ARCH"
    exit 1
    ;;
esac

# Extract prebuilt GHC
mkdir -p bootstrap-src
tar -xof "$BOOTSTRAP_TAR" -C bootstrap-src --strip-components=1

# Configure and install GHC to $OUTPUT_DIR/usr
cd bootstrap-src
./configure --prefix=/usr
make install_bin install_lib update_package_db DESTDIR="$OUTPUT_DIR"

# We also need a libtinfo.so.6, which GHC expects. We copy /usr/lib/libncursesw.so.6.
mkdir -p "$OUTPUT_DIR/usr/lib"
cp -p /usr/lib/libncursesw.so.6 "$OUTPUT_DIR/usr/lib/libtinfo.so.6"

# Let's also copy it in the GHC lib directory:
GHC_LIB_DIR="$OUTPUT_DIR/usr/lib/ghc-${MINIMAL_ARG_VERSION}/lib"
if [ -d "$GHC_LIB_DIR" ]; then
  cp -p /usr/lib/libncursesw.so.6 "$GHC_LIB_DIR/libtinfo.so.6"
fi

# Modify bootstrap settings to use standard ld instead of ld.gold
SETTINGS_FILE="$OUTPUT_DIR/usr/lib/ghc-${MINIMAL_ARG_VERSION}/lib/settings"
if [ -f "$SETTINGS_FILE" ]; then
  sed -i 's/-fuse-ld=gold//g' "$SETTINGS_FILE"
  sed -i 's|/usr/bin/ld.gold|/usr/bin/ld|g' "$SETTINGS_FILE"
fi
