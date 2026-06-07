#!/bin/bash
# Produce a raw, directly-loadable kernel Image from virtio-linux. virtio-linux
# is a build_dep, so its vmlinuz output is present in the sandbox at
# /usr/share/virtio-linux/vmlinuz. On aarch64 that is a gzip-compressed Image
# (Image.gz); decompress it so libkrun can load it via KRUN_KERNEL_FORMAT_RAW
# without an in-VMM gzip step. On x86_64 it is already a bzImage (not gzip), so
# pass it through unchanged.
set -euo pipefail

OUT="$OUTPUT_DIR/usr/share/virtio-linux"
mkdir -p "$OUT"
if gzip -t /usr/share/virtio-linux/vmlinuz 2>/dev/null; then
  gunzip -c /usr/share/virtio-linux/vmlinuz > "$OUT/Image"
else
  cp /usr/share/virtio-linux/vmlinuz "$OUT/Image"
fi
