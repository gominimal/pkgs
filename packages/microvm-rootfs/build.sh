#!/bin/bash
# Assemble a libkrun microVM guest userland as a read-only ext4 image.
#
# The build sandbox hardlinks this package's runtime closure (base + git + their
# libs) and its build-only deps (e2fsprogs, for mke2fs) into the sandbox root at
# standard paths. We snapshot the userland into a staging tree, drop the
# build-only e2fsprogs files, prune bulk, and pack an ext4 image with mke2fs. The
# image is loaded as a virtio-blk block device (/dev/vda); the guest minimald
# ships as the initramfs pid-1, mounts this image, and chroots into it, so the
# image itself carries no standalone init.
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

# e2fsprogs is a build-only dependency: it provides mke2fs to pack the image
# below (invoked from the build sandbox PATH, not from $STAGE), but the guest
# never needs it at runtime. Drop its staged files so the runtime image carries
# only the runtime closure. Remove e2fsprogs's sbin tools by name rather than
# nuking usr/sbin wholesale: iproute2 installs `ip` (and ss/tc/bridge) there
# (SBINDIR=/usr/sbin) and util-linux installs its sbin tools there too — all
# runtime deps that must survive into the guest. The list is e2fsprogs-EXCLUSIVE:
# blkid, findfs, fsck and uuidd are deliberately omitted because util-linux also
# ships those names and its copies are the ones we keep. rm -f tolerates names
# this e2fsprogs config happens not to build.
for tool in badblocks debugfs dumpe2fs e2freefrag e2fsck e2image e2label \
            e2mmpstatus e2scrub e2scrub_all e2undo e4crypt filefrag fsck.ext2 \
            fsck.ext3 fsck.ext4 logsave mke2fs mkfs.ext2 mkfs.ext3 mkfs.ext4 \
            mklost+found resize2fs tune2fs; do
  rm -f "$STAGE/usr/sbin/$tool"
done
rm -f "$STAGE"/usr/bin/chattr "$STAGE"/usr/bin/lsattr "$STAGE"/usr/bin/uuidgen \
      "$STAGE"/usr/bin/compile_et "$STAGE"/usr/bin/mk_cmds
# Note: `libss.so*` (not `libss*.so*`) — the latter also matches openssl's
# libssl.so, which the git runtime closure (curl, openssl) needs at runtime.
rm -f "$STAGE"/usr/lib/libext2fs.so* "$STAGE"/usr/lib/libe2p.so* "$STAGE"/usr/lib/libss.so*

mkdir -p "$STAGE/bin" "$STAGE/sbin"

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
  echo "ERROR: mke2fs not found on PATH ($PATH) — is e2fsprogs in build_deps?" >&2
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
