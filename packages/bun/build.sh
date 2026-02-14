#!/bin/sh
set -ex

python3 -m zipfile -e bun-linux-x64.zip .

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 bun-linux-x64/bun $OUTPUT_DIR/usr/bin/bun
ln -s bun $OUTPUT_DIR/usr/bin/bunx
