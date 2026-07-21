#!/bin/sh
set -e

tar -xof diffoscope-325.tar.gz
cd diffoscope-325

pip3 install --root $OUTPUT_DIR .
# TODO does not produce /usr/bin/diffoscope
# uv pip install --system --prefix $OUTPUT_DIR/usr -r pyproject.toml --extra cmdline
