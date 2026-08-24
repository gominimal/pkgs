#!/bin/sh
set -e

tar -xof "pnpm-${MINIMAL_ARG_VERSION}.tgz"
cd package

install -d $OUTPUT_DIR/usr/{bin,libexec}
cp -R . $OUTPUT_DIR/usr/libexec/pnpm
# npm tarballs don't carry the +x bit on bin scripts (npm sets it at install
# time); `cp -R` preserves the 0644 the tarball ships. pnpm 11.x's bin/*.cjs
# are 0644, so the `/usr/bin/pnpm` symlink would resolve to a non-executable
# file → "Permission denied" (exit 126) when a package builds with pnpm.
chmod +x $OUTPUT_DIR/usr/libexec/pnpm/bin/*.cjs
ln -s ../libexec/pnpm/bin/pnpm.cjs $OUTPUT_DIR/usr/bin/pnpm
ln -s ../libexec/pnpm/bin/pnpx.cjs $OUTPUT_DIR/usr/bin/pnpx
