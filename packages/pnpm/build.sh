#!/bin/sh
set -e

tar xf "pnpm-${MINIMAL_ARG_VERSION}.tgz"
cd package

install -d $OUTPUT_DIR/usr/{bin,libexec}
cp -R . $OUTPUT_DIR/usr/libexec/pnpm
ln -s ../libexec/pnpm/bin/pnpm.cjs $OUTPUT_DIR/usr/bin/pnpm
ln -s ../libexec/pnpm/bin/pnpx.cjs $OUTPUT_DIR/usr/bin/pnpx
