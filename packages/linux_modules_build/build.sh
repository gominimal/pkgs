#!/bin/bash
set -euo pipefail

VERSION="$MINIMAL_ARG_VERSION"

make defconfig
scripts/config --disable MODULE_SIG
scripts/config --disable MODULE_SIG_ALL
scripts/config --disable SYSTEM_TRUSTED_KEYRING
scripts/config --disable SYSTEM_REVOCATION_KEYS
make olddefconfig
make -j"$(nproc)"

DEST="$OUTPUT_DIR/usr/src/linux-${VERSION}"
mkdir -p "$DEST"

cp -a Makefile Kbuild .config Module.symvers "$DEST/" 2>/dev/null || true
cp -a include "$DEST/"
cp -a scripts "$DEST/"
cp -a tools "$DEST/" 2>/dev/null || true

case "$(uname -m)" in
  x86_64)  KARCH=x86 ;;
  aarch64) KARCH=arm64 ;;
  *)       KARCH="$(uname -m)" ;;
esac

mkdir -p "$DEST/arch/${KARCH}"
cp -a "arch/${KARCH}/include" "$DEST/arch/${KARCH}/"
cp -a "arch/${KARCH}/Makefile" "$DEST/arch/${KARCH}/" 2>/dev/null || true
for subdir in tools Makefile.postlink scripts; do
  [ -e "arch/${KARCH}/${subdir}" ] && cp -a "arch/${KARCH}/${subdir}" "$DEST/arch/${KARCH}/" || true
done

find "$DEST/include" "$DEST/arch" -name '*.c' -delete 2>/dev/null || true
find "$DEST" -name '*.o' -delete
find "$DEST" -name '*.cmd' -delete
find "$DEST" -name '.*.cmd' -delete

rm -rf "$DEST/scripts/dtc/include-prefixes"
find "$DEST" -xtype l -delete
