#!/bin/sh
set -e

tar -xof tcl$MINIMAL_ARG_VERSION-src.tar.gz
cd tcl$MINIMAL_ARG_VERSION

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

SRCDIR=$(pwd)
cd unix
./configure  --prefix=/usr            \
            --mandir=/usr/share/man \
            --disable-rpath

make -j$(nproc)

sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh

# The bundled tdbc/itcl versions move between Tcl releases, so read them off the source tree.
TDBC=$(basename "$SRCDIR"/pkgs/tdbc[0-9]*)
ITCL=$(basename "$SRCDIR"/pkgs/itcl[0-9]*)

sed -e "s|$SRCDIR/unix/pkgs/$TDBC|/usr/lib/$TDBC|" \
    -e "s|$SRCDIR/pkgs/$TDBC/generic|/usr/include|" \
    -e "s|$SRCDIR/pkgs/$TDBC/library|/usr/lib/tcl8.6|" \
    -e "s|$SRCDIR/pkgs/$TDBC|/usr/include|" \
    -i pkgs/$TDBC/tdbcConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/$ITCL|/usr/lib/$ITCL|" \
    -e "s|$SRCDIR/pkgs/$ITCL/generic|/usr/include|" \
    -e "s|$SRCDIR/pkgs/$ITCL|/usr/include|" \
    -i pkgs/$ITCL/itclConfig.sh

unset SRCDIR

# make test

make DESTDIR=$OUTPUT_DIR install
make DESTDIR=$OUTPUT_DIR install-private-headers

# Conflicts with a Perl man page
mv $OUTPUT_DIR/usr/share/man/man3/{Thread,Tcl_Thread}.3
# omit sqlite3_analyzer, an example-esque program
rm $OUTPUT_DIR/usr/bin/sqlite3_analyzer
