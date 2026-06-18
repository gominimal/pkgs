#!/bin/sh
set -ex

# The guest kernel source is vendored as a Source; the Makefile expects it
# under tarballs/ and skips its curl download when it is already present.
mkdir -p tarballs
mv linux-*.tar.xz tarballs/

# Build the firmware shared object: compiles the guest kernel, then bundles the
# image into kernel.c via bin2cbundle.py (needs python + pyelftools).
#
# Run a plain in-dir `make -jN` — NOT `make -C` and NOT an exported MAKEFLAGS.
# libkrunfw forwards MAKEFLAGS verbatim into the kernel's recursive make; `-C`
# injects a bare `w` token that the kernel make treats as a goal.
# The sandbox has no `cc` symlink; libkrunfw's Makefile links the firmware .so
# with $(CC) (default cc), so force gcc. The kernel sub-make already defaults to
# gcc, and forwarding CC=gcc to it is harmless.
make CC=gcc -j"$(nproc)"
# Install to lib (not the Makefile's default lib64), matching the repo convention.
make CC=gcc install PREFIX=/usr DESTDIR="$OUTPUT_DIR" LIBDIR_Linux=lib
