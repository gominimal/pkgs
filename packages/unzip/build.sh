#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac

# Info-ZIP unzip 6.0 is frozen (2009); its CVE fixes ship only as distro
# patches. Apply Debian's full 6.0-29 series in order — fixes CVE-2014-8139/
# 8140/8141/9636/9913, CVE-2015-7696/7697, CVE-2016-9844, CVE-2018-1000035,
# CVE-2019-13232, CVE-2022-0529/0530, plus build fixes (incl. patch 30, which
# drops the K&R gmtime()/localtime() declarations that modern GCC rejects — this
# replaces the manual sed that used to live here).
PATCHES=unzip-debian-patches-6.0-29
while IFS= read -r p; do
  [ -n "$p" ] && patch -p1 -i "$PATCHES/$p"
done < "$PATCHES/series"

# Bypass unix/Makefile's autoconfigure (its feature probes misbehave on
# modern glibc and incorrectly set NO_DIR). Build unzips directly with
# LOCAL_UNZIP for the unicode/LFS/NO_LCHMOD defines.
DEFINES="-DLARGE_FILE_SUPPORT -DUNICODE_SUPPORT -DUNICODE_WCHAR -DUTF8_MAYBE_NATIVE -DNO_LCHMOD"
CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir -Wall"
LFLAGS1="-Wl,--build-id=none"

make -f unix/Makefile unzips \
  CC=gcc LD=gcc \
  CFLAGS="$CFLAGS" \
  LOCAL_UNZIP="$DEFINES" \
  LFLAGS1="$LFLAGS1"

mkdir -p "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/share/man/man1"
make -f unix/Makefile install \
  prefix=/usr \
  BINDIR="$OUTPUT_DIR/usr/bin" \
  MANDIR="$OUTPUT_DIR/usr/share/man/man1"
