#!/bin/sh
set -ex

# The release asset is a bare static binary, not an archive — it
# arrives in the cwd under its per-arch name. Pick whichever one this
# arch fetched rather than globbing, so an unexpected extra file fails
# loudly instead of being installed.
if [ -f herdr-linux-x86_64 ]; then
  SRC=herdr-linux-x86_64
elif [ -f herdr-linux-aarch64 ]; then
  SRC=herdr-linux-aarch64
else
  echo "no herdr release binary in the build dir" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 "$SRC" "$OUTPUT_DIR/usr/bin/herdr"
