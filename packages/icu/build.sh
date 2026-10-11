#!/bin/sh
set -e

# The release tarballs carry ICU's data prebuilt (icudt*.dat and the core Unicode property tables). The tag
# tarball has all of it as text, plus the generators; everything below is compiled from that.
tar -xof "icu-release-${MINIMAL_ARG_VERSION}.tar.gz"
S=$PWD/icu-release-${MINIMAL_ARG_VERSION}
C=$S/icu4c/source

# Core property tables: delete the checked-in copies, then regenerate them as ICU's
# data/unidata/generate.sh does, with its gennorm2/genprops/genuca built from its BUILD.bazel files (minibazel.py).
rm -f "$C"/common/norm2_nfc_data.h "$C"/common/propname_data.h "$C"/common/*_props_data.h \
      "$C"/data/in/*.icu "$C"/data/in/*.nrm "$C"/data/in/coll/*.icu
if ls "$C"/data/in/*.dat > /dev/null 2>&1; then
  echo "ERROR: prebuilt ICU data archive in the source tree" >&2
  exit 1
fi
T=$PWD/gen-tools
N=$C/data/unidata/norm2
IN=$C/data/in
python3 minibazel.py "$S" "$T" //icu4c/source/tools/gennorm2
"$T/gennorm2" -o "$C/common/norm2_nfc_data.h" -s "$N" nfc.txt --csource
"$T/gennorm2" -o "$IN/nfc.nrm" -s "$N" nfc.txt
"$T/gennorm2" -o "$IN/nfkc.nrm" -s "$N" nfc.txt nfkc.txt
"$T/gennorm2" -o "$IN/nfkc_cf.nrm" -s "$N" nfc.txt nfkc.txt nfkc_cf.txt
"$T/gennorm2" -o "$IN/nfkc_scf.nrm" -s "$N" nfc.txt nfkc.txt nfkc_scf.txt
"$T/gennorm2" -o "$IN/uts46.nrm" -s "$N" nfc.txt uts46.txt
python3 minibazel.py "$S" "$T" //tools/unicode/c/genprops
"$T/genprops" "$S/icu4c"
python3 minibazel.py "$S" "$T" //tools/unicode/c/genuca
"$T/genuca" --hanOrder implicit "$S/icu4c"
"$T/genuca" --hanOrder radical-stroke "$S/icu4c"
"$T/genuca" --icu4x --hanOrder implicit "$S/icu4c"
"$T/genuca" --icu4x --hanOrder radical-stroke "$S/icu4c"

cd "$C"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
