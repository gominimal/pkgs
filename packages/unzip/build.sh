#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac

# unzip 6.0 (2009) declares gmtime()/localtime() in K&R style, which
# modern GCC rejects as conflicting with <time.h>'s prototypes.
sed -i 's|^   struct tm \*gmtime(), \*localtime();|/* & */|' unix/unxcfg.h

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
