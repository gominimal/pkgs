#!/bin/sh
set -e

# Remove source trees for libraries which are bundled but we build separately.
# configure uses a bundled copy whenever its directory exists, so deleting the
# directory is what selects the registry's library (Debian does the same with
# Files-Excluded). zlib: ghostscript 10.08.0 bundles zlib 1.3.2; with it gone,
# gs links the zlib package, which the libpng and freetype it already uses
# link too (before, one gs process carried two zlibs).
rm -rf freetype lcms2mt jpeg libpng openjpeg zlib

# No OCR: the tesseract + leptonica trees are the largest compile in the
# package (C++), and configure only knows how to use these bundled copies.
# Dropping them removes the ocr, hocr and pdfocr8/24/32 output devices
# (Debian excludes both trees too). Nothing in the registry uses them.
rm -rf tesseract leptonica

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Reproducibility: mkromfs/pack_ps read SOURCE_DATE_EPOCH but then do
# `if (!buildtime) buildtime = time(NULL)`, which treats the sandbox's
# SOURCE_DATE_EPOCH=0 (epoch 0 is falsy) as "unset" and falls back to wall-clock
# time -> non-deterministic gs_romfs_buildtime baked into the gs binary. Only
# fall back to time() when SOURCE_DATE_EPOCH is genuinely unset.
#
# Guard: if a future ghostscript renames the variable or changes this logic,
# fail loudly rather than silently shipping a non-reproducible binary.
for src in base/mkromfs.c base/pack_ps.c; do
  grep -q 'if (!buildtime)' "$src" || {
    echo "ERROR: 'if (!buildtime)' not found in $src — ghostscript changed its SOURCE_DATE_EPOCH handling; update this patch." >&2
    exit 1
  }
done
sed -i 's/if (!buildtime)/if (!env_source_date_epoch)/' base/mkromfs.c base/pack_ps.c

./configure --prefix=/usr \
            --disable-static \
            --with-system-libtiff \
            --disable-compiler-inits \
            --without-tesseract \
            CFLAGS="${CFLAGS:--g -O3} -fPIC"

# Fail closed if configure fell back to a bundled zlib or kept OCR (a future
# release could add a new copy or change the detection).
grep -qx 'SHARE_ZLIB=1' Makefile || { echo "ERROR: configure did not select the system zlib" >&2; exit 1; }
grep -qx 'OCR_VERSION=0' Makefile || { echo "ERROR: OCR (tesseract) is still enabled" >&2; exit 1; }

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install

# Fail closed: gs must link the registry's zlib (libz.so.1), and without
# tesseract it is plain C, so it must not need libstdc++ (build.ncl no longer
# carries libstdcpp as a runtime dep).
command -v readelf >/dev/null
needed=$(readelf -d "$OUTPUT_DIR/usr/bin/gs" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
echo "gs NEEDED:" $needed
echo "$needed" | grep -qx 'libz\.so\.1' || { echo "ERROR: gs does not need libz.so.1" >&2; exit 1; }
if echo "$needed" | grep -q '^libstdc++'; then
  echo "ERROR: gs needs libstdc++; add libstdcpp back to runtime_deps" >&2
  exit 1
fi
