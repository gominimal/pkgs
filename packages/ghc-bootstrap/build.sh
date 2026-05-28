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

# Find the real ncurses library dynamically
NCURSES_PATH=""
for path in \
  /usr/lib/libncursesw.so.6 \
  /usr/lib/libncurses.so.6 \
  /usr/lib64/libncursesw.so.6 \
  /usr/lib64/libncurses.so.6 \
  /lib/*/libncursesw.so.6 \
  /lib/*/libncurses.so.6 \
  /usr/lib/*/libncursesw.so.6 \
  /usr/lib/*/libncurses.so.6 \
  /lib/libncursesw.so.6 \
  /lib/libncurses.so.6; do
  if [ -f "$path" ]; then
    NCURSES_PATH="$path"
    break
  fi
done

if [ -z "$NCURSES_PATH" ]; then
  if command -v gcc >/dev/null 2>&1; then
    for libname in libncursesw.so.6 libncurses.so.6; do
      GCC_FOUND_PATH="$(gcc -print-file-name=$libname)"
      if [ -f "$GCC_FOUND_PATH" ]; then
        NCURSES_PATH="$GCC_FOUND_PATH"
        break
      fi
    done
  fi
fi

if [ -z "$NCURSES_PATH" ]; then
  if command -v ldconfig >/dev/null 2>&1; then
    for libname in libncursesw.so.6 libncurses.so.6; do
      LDCONFIG_PATH="$(ldconfig -p | grep "$libname" | head -n1 | awk '{print $NF}')"
      if [ -f "$LDCONFIG_PATH" ]; then
        NCURSES_PATH="$LDCONFIG_PATH"
        break
      fi
    done
  fi
fi

if [ -z "$NCURSES_PATH" ]; then
  echo "Error: Could not locate libncursesw.so.6 or libncurses.so.6" >&2
  exit 1
fi

# We also need a libtinfo.so.6, which GHC expects.
mkdir -p "$OUTPUT_DIR/usr/lib"
cp -p "$NCURSES_PATH" "$OUTPUT_DIR/usr/lib/libtinfo.so.6"

# Let's also copy it in the GHC lib directory:
GHC_LIB_DIR="$OUTPUT_DIR/usr/lib/ghc-${MINIMAL_ARG_VERSION}/lib"
if [ -d "$GHC_LIB_DIR" ]; then
  cp -p "$NCURSES_PATH" "$GHC_LIB_DIR/libtinfo.so.6"
fi

# Modify bootstrap settings to use standard ld instead of ld.gold
SETTINGS_FILE="$OUTPUT_DIR/usr/lib/ghc-${MINIMAL_ARG_VERSION}/lib/settings"
if [ -f "$SETTINGS_FILE" ]; then
  sed -i 's/-fuse-ld=gold//g' "$SETTINGS_FILE"
  sed -i 's|/usr/bin/ld.gold|/usr/bin/ld|g' "$SETTINGS_FILE"
fi
