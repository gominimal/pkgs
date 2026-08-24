#!/bin/bash
# Assemble a libkrun microVM guest userland as a read-only ext4 image.
#
# Everything in the image comes from the pinned upstream Alpine artifacts
# build.ncl fetches into this directory: the minirootfs tarball (musl libc +
# busybox + baselayout) unpacked as the base, overlaid with the sha256-pinned
# closure of .apk files for the tools busybox does not cover. This build no
# longer snapshots the sandbox root, so none of this repo's packages — and no
# glibc — reach the image.
#
# The image is packed with mke2fs from the e2fsprogs *build* dep (on PATH) and
# loaded as a virtio-blk block device (/dev/vda); the guest minimald ships as
# the initramfs pid-1, mounts this image and chroots into it, so the image
# itself carries no init and no minimald. e2fsprogs (mkfs.ext4) and fstrim ship
# in the image so the guest can format and reclaim the per-VM writable volume
# (/dev/vdb) mounted at /var/lib/minimal.
set -euo pipefail

STAGE="$(pwd)/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"

# Base userland. The minirootfs tarball is a complete rootfs with no top-level
# directory, so it unpacks straight into the staging root. Its own paths carry
# the modes the image needs (/tmp 1777, /root 0700).
shopt -s nullglob
minirootfs=(alpine-minirootfs-*.tar.gz)
if [ "${#minirootfs[@]}" -ne 1 ]; then
  echo "ERROR: expected exactly 1 minirootfs tarball, found ${#minirootfs[@]}: ${minirootfs[*]}" >&2
  exit 1
fi
tar -xzf "${minirootfs[0]}" -C "$STAGE"

# Overlay the pinned .apk closure. An .apk is a gzipped tar, so it is unpacked
# with tar rather than apk — the guest root is read-only and nothing in the
# closure has an install script to run (the busybox applet symlinks and the CA
# bundle that do need one are already applied in the minirootfs). Unpack via a
# scratch dir so apk's own metadata entries — dotfiles at the archive root
# (.PKGINFO, .SIGN.*, .pre-/.post-install, .trigger) — can be dropped before
# the payload is merged into the staging tree.
#
# The merge goes through tar rather than cp so that a destination entry is
# replaced rather than written through: several of these packages ship a real
# binary where the minirootfs has a busybox applet symlink (/sbin/ip and
# /sbin/fstrim point at /bin/busybox), and copying onto the symlink would
# follow it and overwrite busybox itself.
#
# --warning=no-unknown-keyword: apk records per-file checksums in a pax header
# keyword tar does not know, and would otherwise warn about once per file.
apks=(*.apk)
if [ "${#apks[@]}" -eq 0 ]; then
  echo "ERROR: no .apk sources in $(pwd)" >&2
  exit 1
fi
SCRATCH="$(pwd)/apk-payload"
for a in "${apks[@]}"; do
  rm -rf "$SCRATCH"
  mkdir -p "$SCRATCH"
  tar --warning=no-unknown-keyword -xzf "$a" -C "$SCRATCH"
  find "$SCRATCH" -mindepth 1 -maxdepth 1 -name '.*' -exec rm -rf {} +
  tar -cf - -C "$SCRATCH" . | tar -xof - -C "$STAGE"
done
rm -rf "$SCRATCH"

# Per-VM writable volume mountpoint. The guest minimald mounts /dev/vdb here on
# first boot (after formatting it with mkfs.ext4). The root image is mounted
# read-only, so this directory cannot be created at runtime — it must ship in
# the image or the mount fails with ENOENT/EROFS.
mkdir -p "$STAGE/var/lib/minimal"

# Resolver mountpoint. The guest minimald points DNS at the switch's server by
# writing /run/resolv.conf and bind-mounting it over /etc/resolv.conf. A bind
# only changes the mount tree, so it works on this read-only root — but only if
# the target path already exists. The Alpine minirootfs ships no resolv.conf
# (the old sandbox-snapshot image inherited one from the build root), so without
# this the mount fails with ENOENT, the guest has no resolver at all, and
# anything that resolves a name — the in-guest `pkgs` clone during session mint
# — dies with "Could not resolve host". Empty on purpose: the contents are
# written at runtime, this only reserves the path.
: > "$STAGE/etc/resolv.conf"

# bash's loadable builtins (~2.7 MB) are only reachable via `enable -f`, which
# nothing in the guest uses. This is the one payload the .apk closure ships that
# the guest does not need: Alpine splits headers, static libs, man pages and
# docs into -dev/-doc subpackages that are not in the closure at all, so there
# is nothing else to prune.
rm -rf "$STAGE/usr/lib/bash"

# Assert the guest tools landed where the boot contract expects them, so a
# silently-empty .apk or an upstream path move fails here rather than at guest
# boot. One entry per root package in build.ncl, plus busybox from the
# minirootfs; the musl loader is checked separately below.
for f in \
  bin/busybox \
  bin/bash \
  bin/sh \
  usr/bin/git \
  sbin/ip \
  sbin/mkfs.ext4 \
  sbin/fstrim \
  usr/bin/nsenter; do
  # -L as well as -e: /bin/sh is an absolute symlink to /bin/busybox, which
  # only resolves once the image is the root.
  [ -e "$STAGE/$f" ] || [ -L "$STAGE/$f" ] || {
    echo "ERROR: expected /$f in the staged rootfs" >&2
    exit 1
  }
done
# musl's loader is the only interpreter in the image; if it is missing, or a
# glibc loader appears, the image is not what this package claims to build.
compgen -G "$STAGE/lib/ld-musl-*.so.1" >/dev/null || {
  echo "ERROR: no musl loader in the staged rootfs" >&2
  exit 1
}
if [ -e "$STAGE/lib64" ] || compgen -G "$STAGE/lib/ld-linux*" >/dev/null; then
  echo "ERROR: glibc loader in the staged rootfs — a glibc dep leaked in" >&2
  exit 1
fi

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
echo "built rootfs.img: $(wc -c < "$OUT/rootfs.img") bytes (staged tree ${KB} KiB)"
