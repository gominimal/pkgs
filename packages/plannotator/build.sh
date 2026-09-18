#!/bin/sh
set -ex

# Bare static binary per arch, not an archive.
if [ -f plannotator-linux-x64 ]; then
  SRC=plannotator-linux-x64
elif [ -f plannotator-linux-arm64 ]; then
  SRC=plannotator-linux-arm64
else
  echo "no plannotator release binary in the build dir" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 "$SRC" "$OUTPUT_DIR/usr/bin/plannotator"
