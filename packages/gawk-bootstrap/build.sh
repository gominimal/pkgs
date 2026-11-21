#!/bin/sh
set -e

tar -xof gawk-5.4.1.tar.xz
cd gawk-5.4.1

sed -i 's/extras//' Makefile.in

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
            --without-readline

make -j$(nproc)

# Install ONLY the interpreter, as usr/bin/awk: a real file, not upstream's
# awk -> gawk symlink. Every other path gawk installs (usr/bin/gawk*,
# usr/lib/gawk, usr/libexec/awk, usr/include, usr/share/{awk,man,locale})
# belongs to packages/gawk, which takes its awk from here, so the two packages
# never install the same path (gominimal/pkgs#973). The name is `awk`, not
# `gawk`: base-bootstrap carries this package into every build sandbox, where
# configure's AC_PROG_AWK and Makefiles find it as `awk`. A recipe that needs
# `gawk` by name imports packages/gawk.
install -D -m 755 gawk "$OUTPUT_DIR/usr/bin/awk"
