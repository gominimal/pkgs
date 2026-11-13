#!/bin/sh
set -ex

# The guest kernel source (a pre-patched libkrun/linux tag archive) is vendored
# as a Source; the Makefile expects it at
#   KERNEL_TARBALL = tarballs/v$(FULL_VERSION)-$(KERNEL_VERSION).tar.gz
# and skips its curl download when it is already present. Derive that name from
# the Makefile and fail loudly if the layout changed or the vendored tarball
# does not match it -- otherwise make falls back to curl, which the hermetic
# sandbox reports only as "make: curl: No such file or directory".
grep -qx 'KERNEL_TARBALL = tarballs/v$(FULL_VERSION)-$(KERNEL_VERSION).tar.gz' Makefile || {
  echo "libkrunfw Makefile KERNEL_TARBALL changed; update build.ncl's kernel Source:" >&2
  grep -n '^KERNEL_' Makefile >&2
  exit 1
}
full_version=$(sed -n 's/^FULL_VERSION = //p' Makefile)
kernel_version=$(sed -n 's/^KERNEL_VERSION = //p' Makefile)
kernel_tarball="v${full_version}-${kernel_version}.tar.gz"
[ -f "$kernel_tarball" ] || {
  echo "libkrunfw Makefile wants $kernel_tarball (KERNEL_VERSION=$kernel_version) but it is not vendored:" >&2
  ls -1 v*-*.tar.gz >&2 || true
  echo "bump kernel_version / the kernel Source in build.ncl" >&2
  exit 1
}
mkdir -p tarballs
mv "$kernel_tarball" tarballs/

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
