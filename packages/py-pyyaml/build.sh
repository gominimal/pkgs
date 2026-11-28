#!/bin/sh
set -ex

# setup.py reads this: leave out the libyaml extension.
export PYYAML_FORCE_LIBYAML=0

pip3 wheel -w dist --no-index --no-build-isolation --no-deps --no-cache-dir "$(pwd)"
pip3 install --no-index --find-links dist --no-deps --no-user --root "$OUTPUT_DIR" pyyaml
