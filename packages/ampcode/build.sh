#!/bin/sh
# Imported from the Homebrew formula `ampcode/homebrew-tap/ampcode` by `pkgmgr import homebrew`.
# Prebuilt vendor binary: unpacked and installed, never compiled.
set -ex

install -D -m 755 "amp-linux-${MINIMAL_ARG_ARCH}" "$OUTPUT_DIR/usr/bin/amp"
