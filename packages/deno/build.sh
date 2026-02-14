#!/bin/sh
set -ex

python3 -m zipfile -e deno-x86_64-unknown-linux-gnu.zip .

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 deno $OUTPUT_DIR/usr/bin/deno
