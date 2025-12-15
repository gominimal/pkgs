#!/bin/sh
set -e

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD

pip3 install --root $OUTPUT_DIR --no-index --find-links dist meson
