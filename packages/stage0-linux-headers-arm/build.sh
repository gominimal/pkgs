#!/bin/sh
set -ex

tar -xof linux-6.12.43.tar.xz
cd linux-6.12.43

# Plain `make headers`, as the production linux_headers recipe does. The host compiler needs
# <linux/errno.h> and <asm/errno.h> to build scripts/unifdef; those come from the hydrated
# linux_headers package (see build.ncl for why that is a deliberate generation-1 compromise and
# not a cycle). The EXPORTED headers below are produced from the kernel source, not copied from it.
make headers

mkdir -p $OUTPUT_DIR/usr
cp -rv usr/include $OUTPUT_DIR/usr/
