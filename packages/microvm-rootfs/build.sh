#!/bin/bash
# Assemble a libkrun microVM guest userland as a read-only ext4 image.
#
# The build sandbox hardlinks this package's runtime closure (base + git +
# iproute2 + e2fsprogs + util-linux + their libs) into the sandbox root at
# standard paths. We snapshot the userland into a staging tree, prune build-only
# bulk, and pack an ext4 image with mke2fs (from the e2fsprogs runtime closure,
# on PATH). The image is loaded as a virtio-blk block device (/dev/vda); the
# guest minimald ships as the initramfs pid-1, mounts this image, and chroots
# into it, so the image itself carries no standalone init. e2fsprogs (mkfs.ext4)
# and util-linux (fstrim) ship in the image so the guest can format and reclaim
# the per-VM writable volume (/dev/vdb) mounted at /var/lib/minimal.
set -euo pipefail

STAGE="$(pwd)/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"

# Snapshot the runtime userland composed into this build sandbox.
for d in usr bin sbin lib lib64 etc; do
  if [ -e "/$d" ]; then
    cp -a "/$d" "$STAGE/"
  fi
done

mkdir -p "$STAGE/bin" "$STAGE/sbin"

# Per-VM writable volume mountpoint. The guest minimald mounts /dev/vdb here on
# first boot (after formatting it with mkfs.ext4). The root image is mounted
# read-only, so this directory cannot be created at runtime — it must ship in
# the image or the mount fails with ENOENT/EROFS.
mkdir -p "$STAGE/var/lib/minimal"

# Kernel mountpoints. devtmpfs auto-mounts on /dev at boot (CONFIG_DEVTMPFS_MOUNT)
# — without the directory it fails with "devtmpfs: error mounting -2" and the
# guest has no /dev/vsock node. /proc and /sys are conventional mountpoints.
mkdir -p "$STAGE/dev" "$STAGE/proc" "$STAGE/sys" "$STAGE/run" "$STAGE/tmp"
chmod 1777 "$STAGE/tmp"

# Guarantee /bin/sh: the in-guest minimald chroots in and runs /bin/bash, but a
# /bin/sh is conventional for any script the session shells out to.
if [ ! -e "$STAGE/bin/sh" ]; then
  if [ -e "$STAGE/bin/bash" ]; then
    ln -sf bash "$STAGE/bin/sh"
  elif [ -e "$STAGE/usr/bin/bash" ]; then
    ln -sf ../usr/bin/bash "$STAGE/bin/sh"
  fi
fi

# Prune build-time-only bulk the guest never needs: headers, static libs,
# docs/man, and especially glibc's locale archive (the bulk of the closure).
# The C locale fallback is sufficient for the guest workload.
# `|| true` is scoped to `find` only — a failure in `cd` or `rm -rf` must still
# fail the build (set -euo pipefail), while `find`'s noncritical errors are ok.
( cd "$STAGE" && \
  rm -rf usr/include usr/share/man usr/share/doc usr/share/info \
         usr/share/locale usr/share/i18n usr/lib/locale usr/lib/pkgconfig \
         usr/share/aclocal usr/share/gtk-doc usr/share/bash-completion \
         usr/share/gdb && \
  { find . \( -name '*.a' -o -name '*.la' -o -name '*.o' \) -delete 2>/dev/null || true; } )

# Fail loudly (not silently with an empty output) if the image tool is absent.
command -v mke2fs >/dev/null || {
  echo "ERROR: mke2fs not found on PATH ($PATH) — is e2fsprogs in runtime_deps?" >&2
  exit 1
}

# Pack the staging tree into a raw ext4 image (mke2fs -d copies the tree).
# Size = tree + 10% + 8 MiB headroom, in 1 KiB blocks. The headroom must cover
# ext4 metadata (inode tables) that `du` does not account for, or `mke2fs -d`
# can fail to fit the tree.
OUT="$OUTPUT_DIR/usr/share/microvm-rootfs"
mkdir -p "$OUT"
KB="$(du -sk "$STAGE" | cut -f1)"
BLOCKS=$(( KB + KB / 10 + 8192 ))
# No journal (`-O ^has_journal`): the root mounts read-only, so the journal is
# pure overhead and its ~4 MiB+ reservation can overflow a tight image.
#
# Reproducibility: mke2fs otherwise randomizes the filesystem UUID and the
# directory hash seed and stamps the current time on every inode. Pin all three
# (fixed UUID + hash seed; SOURCE_DATE_EPOCH for inode/superblock times) so the
# image is byte-identical across builds.
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-0}"
ROOTFS_UUID=00112233-4455-6677-8899-aabbccddeeff
mke2fs -q -t ext4 -O ^has_journal \
  -U "$ROOTFS_UUID" -E hash_seed="$ROOTFS_UUID" \
  -d "$STAGE" -b 1024 -F "$OUT/rootfs.img" "$BLOCKS"

# Assert the output exists so a silent mke2fs failure surfaces here rather than
# downstream as a missing materialize output.
[ -s "$OUT/rootfs.img" ] || {
  echo "ERROR: mke2fs did not produce $OUT/rootfs.img" >&2
  ls -la "$OUT" >&2 || true
  exit 1
}
echo "built rootfs.img: $(wc -c < "$OUT/rootfs.img") bytes"
