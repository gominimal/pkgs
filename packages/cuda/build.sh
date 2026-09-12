#!/bin/bash
set -euo pipefail

DEST="$OUTPUT_DIR/opt/cuda"
mkdir -p "$DEST"

for d in *-archive; do
  [ -d "$d" ] || continue
  (cd "$d" && tar -cf - .) | tar -xof - -C "$DEST"
done

cd "$DEST"
if [ -d lib ] && [ ! -e lib64 ]; then
  ln -s lib lib64
fi

