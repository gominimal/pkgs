#!/bin/sh
set -ex

python3 rebuild-llhttp-wasm.py selftest
install -Dm 0644 rebuild-llhttp-wasm.py "$OUTPUT_DIR/usr/share/llhttp-wasm-rebuild/rebuild-llhttp-wasm.py"
