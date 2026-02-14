#!/bin/sh
set -e

tar xfo perl-5.42.0.tar.xz
cd perl-5.42.0

export BUILD_ZLIB=False
export BUILD_BZIP2=0
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

sh Configure  -des                                          \
             -D cc=gcc                                     \
             -D prefix=/usr                                 \
             -D vendorprefix=/usr                           \
             -D privlib=/usr/lib/perl5/5.42/core_perl      \
             -D archlib=/usr/lib/perl5/5.42/core_perl      \
             -D sitelib=/usr/lib/perl5/5.42/site_perl      \
             -D sitearch=/usr/lib/perl5/5.42/site_perl     \
             -D vendorlib=/usr/lib/perl5/5.42/vendor_perl  \
             -D vendorarch=/usr/lib/perl5/5.42/vendor_perl \
             -D man1dir=/usr/share/man/man1                \
             -D man3dir=/usr/share/man/man3                \
             -D pager="/usr/bin/less -isR"                 \
             -D useshrplib                                 \
             -D usethreads

make -j$(nproc)
# TEST_JOBS=$(nproc) make test_harness # TODO there are failures
make DESTDIR=$OUTPUT_DIR install-strip
