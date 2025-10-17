#!/bin/sh
set -e

tar xf diffoscope-306.tar.gz
cd diffoscope-306

pip3 install --root $OUTPUT_DIR .
# TODO does not produce /usr/bin/diffoscope
# uv pip install --system --prefix $OUTPUT_DIR/usr -r pyproject.toml --extra cmdline
