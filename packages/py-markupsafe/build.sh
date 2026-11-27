#!/bin/sh
set -ex

pip3 wheel -w dist --no-index --no-build-isolation --no-deps --no-cache-dir "$(pwd)"
pip3 install --no-index --find-links dist --no-deps --no-user --root "$OUTPUT_DIR" markupsafe
