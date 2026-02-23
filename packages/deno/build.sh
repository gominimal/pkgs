#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  DENOARCH=x86_64 ;;
  aarch64) DENOARCH=aarch64 ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

python3 -m zipfile -e "deno-${DENOARCH}-unknown-linux-gnu.zip" .

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 deno $OUTPUT_DIR/usr/bin/deno
