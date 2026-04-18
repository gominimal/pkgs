#!/bin/sh
set -e

tar -xof "setuptools-$MINIMAL_ARG_VERSION.tar.gz"
cd "setuptools-$MINIMAL_ARG_VERSION"

pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --root $OUTPUT_DIR --no-index --find-links dist setuptools
