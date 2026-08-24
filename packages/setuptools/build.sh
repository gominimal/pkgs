#!/bin/sh
set -e

tar -xof "setuptools-$MINIMAL_ARG_VERSION.tar.gz"
cd "setuptools-$MINIMAL_ARG_VERSION"

# Build with PEP 517 build isolation. python 3.14.6 ships pip 26, which dropped
# the fallback that let `--no-build-isolation` self-build setuptools without an
# already-installed setuptools backend — so the old recipe fails with
# `invalid command 'dist_info'` on ANY setuptools rebuild. minimal's clean room
# pre-stages the backend, so isolation resolves offline.
pip3 wheel -w dist --no-cache-dir --no-deps "$PWD"
pip3 install --root "$OUTPUT_DIR" --no-index --find-links dist setuptools
