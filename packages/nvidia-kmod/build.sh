#!/bin/bash
set -euo pipefail

VERSION="$MINIMAL_ARG_VERSION"
KVER="$MINIMAL_ARG_KERNEL_VERSION"
KSRC_RO="/usr/src/linux-${KVER}"

KSRC="$(pwd)/linux-${KVER}"
cp -a "$KSRC_RO" "$KSRC"
chmod -R u+w "$KSRC"

export CC=gcc
export HOSTCC=gcc
export LD=ld

make modules -j"$(nproc)" \
  CC=gcc HOSTCC=gcc LD=ld \
  SYSSRC="$KSRC" \
  SYSOUT="$KSRC" \
  IGNORE_PREEMPT_RT_PRESENCE=1 \
  IGNORE_MISSING_MODULE_SYMVERS=1 \
  TARGET_ARCH=x86_64

DEST="$OUTPUT_DIR/lib/modules/${KVER}/kernel/drivers/video"
mkdir -p "$DEST"
for m in nvidia nvidia-uvm nvidia-modeset nvidia-drm nvidia-peermem; do
  if [ -f "kernel-open/${m}.ko" ]; then
    cp "kernel-open/${m}.ko" "$DEST/"
  fi
done
