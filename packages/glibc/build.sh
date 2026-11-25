#!/bin/sh
set -e

tar -xof "glibc-${MINIMAL_ARG_VERSION}.tar.xz"
cd "glibc-${MINIMAL_ARG_VERSION}"

# glibc 2.44 release branch (release/2.44/master up to 809fd7179d, 2.44-87):
# the 12 open 2.44 CVEs plus the branch's other backported fixes, carried as
# one diff the way Debian's git-updates.diff does (see build.ncl and the
# patch header for the commit list). Applied before configure so a failed
# hunk fails the build under `set -e`; -F0 refuses fuzzy hunks so a context
# drift on a later bump fails too instead of landing elsewhere. The patch
# lives one level up because we extracted into a subdirectory above. Drop it
# on the bump to 2.45 (or rebase it onto 2.44.1 if that is ever tagged).
patch -Np1 -F0 -i "../0001-glibc-2.44-release-branch-809fd7179d.patch"
# Last commit in the range adds this test; its presence proves the whole
# patch went in, not a prefix of it.
test -f posix/tst-glob-nospace.c

mkdir -v build
cd build

echo "rootsbindir=/usr/sbin" > configparms

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"
export ARFLAGS=Drc

../configure --prefix=/usr                  \
            --disable-werror                \
            --disable-nscd                  \
            libc_cv_slibdir=/usr/lib        \
            --enable-stack-protector=strong \
            --enable-kernel=6.1

make -j$(nproc)
# TODO way too slow
# make check
make DESTDIR=$OUTPUT_DIR install

sed '/RTLDLIST=/s@/usr@@g' -i $OUTPUT_DIR/usr/bin/ldd

mkdir -vp $OUTPUT_DIR/usr/lib/locale
localedef --prefix=$OUTPUT_DIR -i en_US -f ISO-8859-1 en_US
localedef --prefix=$OUTPUT_DIR -i en_US -f UTF-8 en_US.UTF-8
