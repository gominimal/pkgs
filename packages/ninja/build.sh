#!/bin/sh
set -e

python3 configure.py --bootstrap --verbose

mkdir -v -p $OUTPUT_DIR/usr/bin
install -vm755 ninja $OUTPUT_DIR/usr/bin/
