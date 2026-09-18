#!/bin/sh
set -ex

# The tarball holds exactly one member — the `antigravity` binary — and the
# Source is declared extract=true, so it is already unpacked in the cwd.
if [ ! -f antigravity ]; then
  echo "expected an 'antigravity' binary from the extracted tarball" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 antigravity "$OUTPUT_DIR/usr/bin/antigravity"
