#!/bin/sh
set -ex

export LIBSQLITE3_SYS_USE_PKG_CONFIG=1
export LIBSSH2_SYS_USE_PKG_CONFIG=1
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Hermetic stage0 bootstrap. The stage0 toolchain tarballs (rustc,
# cargo, rust-std for the previous stable) are declared as `extract =
# false` Source build_deps in build.ncl, so minimal's source hydration
# drops them in this build's CWD. x.py's bootstrap looks for stage0
# under build/cache/<compiler_date>/ — pre-place them there so it uses
# the local copies instead of curling static.rust-lang.org (there is no
# network egress in Confidential Space).
#
# The date is read from the rust source's own src/stage0 manifest when
# parseable, so it self-corrects on a version bump; the fallback matches
# the currently-pinned rust version's stage0 (keep it in sync with the
# build.ncl stage0 Source URLs when bumping rust).
STAGE0_DATE=$(sed -n 's/^compiler_date=//p' src/stage0 2>/dev/null | head -1)
: "${STAGE0_DATE:=2026-03-05}"
echo "rust stage0: placing local bootstrap tarballs under build/cache/$STAGE0_DATE/"
mkdir -p "build/cache/$STAGE0_DATE"
cp -v ./rustc-*.tar.xz ./cargo-*.tar.xz ./rust-std-*.tar.xz "build/cache/$STAGE0_DATE/"

./x.py build

DESTDIR=$OUTPUT_DIR ./x.py install

rm $OUTPUT_DIR/usr/bin/rust-gdbgui
