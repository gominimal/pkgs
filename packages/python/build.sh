#!/bin/sh
set -e

tar -xof "Python-${MINIMAL_ARG_VERSION}.tar.xz"
cd "Python-${MINIMAL_ARG_VERSION}"

# CVE-2026-19672 -- see the patch header and the note in build.ncl. Applied
# before configure so a failed hunk fails the build under `set -e` rather than
# quietly producing a python whose tarfile filters still escape. The patch
# lives one level up because we extracted into a subdirectory above.
patch -Np1 -i "../0001-gh-155999-tarfile-normalize-parent-dir-components.patch"

# CVE-2026-15806 (urllib), CVE-2026-15310 (zipfile) and CVE-2026-17084
# (stringprep/idna) -- same deal: 3.14-branch backports that first ship in
# 3.14.8. 0004 carries two upstream commits that must apply in order; they
# live in one file so that order cannot be got wrong. 0002 is reserved for
# the tarfile fix in pkgs#765.
patch -Np1 -i "../0003-gh-155694-urllib-scope-credentials-by-scheme.patch"
patch -Np1 -i "../0004-gh-156002-zipfile-bound-decompression.patch"
patch -Np1 -i "../0005-gh-155292-stringprep-pin-unicode-3.2.patch"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# -fno-semantic-interposition: drops PLT indirection on internal libpython calls
# — a deterministic perf win for --enable-shared that --enable-optimizations used
# to add implicitly. Re-added by hand since we drop --enable-optimizations below.
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir -fno-semantic-interposition"
export LDFLAGS="-Wl,--build-id=none -fno-semantic-interposition"
export CXXFLAGS="${CFLAGS}"

# Reproducibility (two parts):
#  - libffi pin: make configure resolve MODULE__CTYPES_LDFLAGS deterministically
#    ('-lffi') instead of letting PKG_CHECK_MODULES non-deterministically pick
#    -L/usr/lib/../lib64 vs ../lib (which leaks into _sysconfigdata*.py/.json).
#  - drop PGO: --enable-optimizations runs a gcc PGO training pass whose .gcda
#    counters are NOT reproducible. Measured: building instrumented once and
#    running `-m test --pgo` twice, 216 of 334 .gcda differ (64%) — across the
#    core interpreter/parser/compiler, and some even differ in size (different
#    functions execute run-to-run), even with the hash seed pinned. No gcc flag
#    fixes the training DATA, and the workload can't be pinned without a stored
#    profile. Dropping it makes .text byte-identical; -fno-semantic-interposition
#    above recovers the main deterministic perf the flag had bundled.
#    (NOTE: --with-lto=full is also NOT deterministic here — WHOPR partitioning
#    perturbs libpython layout build-to-build; use -flto=1 if LTO perf is wanted.)
./configure  --prefix=/usr          \
            --enable-shared         \
            --with-system-expat     \
            --without-static-libpython \
            LIBFFI_CFLAGS="-I/usr/include" \
            LIBFFI_LIBS="-lffi"

make -j$(nproc)
# TODO
#make test TESTOPTS="--timeout 120"
make DESTDIR=$OUTPUT_DIR install
