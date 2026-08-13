#!/bin/sh
# Imported from the Homebrew formula `ampcode/homebrew-tap/zvelte-check` by `pkgmgr import homebrew`.
# Prebuilt vendor binary: unpacked and installed, never compiled.
set -ex

tar -xof "zvelte-check-linux-${MINIMAL_ARG_ARCH}.tar.gz"
install -D -m 755 "zvelte-check" "$OUTPUT_DIR/usr/bin/zvelte-check"
