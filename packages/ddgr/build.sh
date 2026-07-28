#!/bin/sh
# Auto-bootstrapped by `pkgmgr bootstrap` (ddgr 2.2, python).
set -eu

# Build a wheel from the source tree with the in-environment setuptools
# backend (no build isolation, no network), then install it into $OUTPUT_DIR.
# `--no-deps` on both steps: Minimal provides runtime deps as its own packages,
# so pip must NOT resolve them from the (empty) index.
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$(pwd)"
pip3 install --no-index --find-links dist --no-deps --no-user --root "$OUTPUT_DIR" ddgr
