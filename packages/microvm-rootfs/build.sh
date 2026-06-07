#!/bin/bash
# Assemble a libkrun microVM guest rootfs as a read-only ext4 image.
#
# The build sandbox hardlinks this package's build_deps and their runtime
# closure (socat, bash, coreutils, e2fsprogs + glibc/readline/ncurses/openssl)
# into the sandbox root at standard paths. We snapshot that userland into a
# staging tree, drop in a small bring-up init, and pack it with mke2fs. The
# image is loaded as a virtio-blk block device (e.g. root=/dev/vda); a block
# root has no overlaid init, so the kernel runs the init below directly.
# devtmpfs auto-mounts /dev, giving the init /dev/vsock.
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

mkdir -p "$STAGE/bin" "$STAGE/sbin" "$STAGE/etc/microvm"

# Kernel mountpoints. devtmpfs auto-mounts on /dev at boot (CONFIG_DEVTMPFS_MOUNT)
# — without the directory it fails with "devtmpfs: error mounting -2" and the
# guest has no /dev/vsock node. /proc and /sys are conventional mountpoints.
mkdir -p "$STAGE/dev" "$STAGE/proc" "$STAGE/sys" "$STAGE/run" "$STAGE/tmp"
chmod 1777 "$STAGE/tmp"

# Guarantee /bin/sh for the init script's shebang.
if [ ! -e "$STAGE/bin/sh" ]; then
  if [ -e "$STAGE/bin/bash" ]; then
    ln -sf bash "$STAGE/bin/sh"
  elif [ -e "$STAGE/usr/bin/bash" ]; then
    ln -sf ../usr/bin/bash "$STAGE/bin/sh"
  fi
fi

# Bring-up init: signal readiness by connecting out to the host (vsock CID 2)
# port 7350 and writing "READY\n", then serve an echo on vsock port 2222 for
# host<->guest connectivity checks. Retry the marker briefly in case the vsock
# device is not live the instant init starts.
cat > "$STAGE/sbin/microvm-init" <<'INIT'
#!/bin/sh
i=0
while [ "$i" -lt 50 ]; do
    printf 'READY\n' | socat -t2 - VSOCK-CONNECT:2:7350 && break
    i=$((i + 1))
    sleep 0.1
done
exec socat VSOCK-LISTEN:2222,fork EXEC:cat
INIT
chmod +x "$STAGE/sbin/microvm-init"

# Machine-readable record of the bring-up contract.
cat > "$STAGE/etc/microvm/manifest" <<'MANIFEST'
# microvm guest rootfs contract
# format=ext4-block-image
# init=/sbin/microvm-init
# vsock_port_ready=7350    guest CONNECTs out (host listen=false); writes "READY\n" once
# vsock_port_echo=2222     guest LISTENs (host listen=true); echoes per connection
# net=none
MANIFEST

# Prune build-time-only bulk the guest never needs: headers, static libs,
# docs/man, and especially glibc's locale archive (the bulk of the closure).
# The bring-up workload is sh + socat; the C locale fallback is sufficient.
( cd "$STAGE" && \
  rm -rf usr/include usr/share/man usr/share/doc usr/share/info \
         usr/share/locale usr/share/i18n usr/lib/locale usr/lib/pkgconfig \
         usr/share/aclocal usr/share/gtk-doc usr/share/bash-completion \
         usr/share/gdb && \
  find . \( -name '*.a' -o -name '*.la' -o -name '*.o' \) -delete 2>/dev/null || true )

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
mke2fs -q -t ext4 -O ^has_journal -d "$STAGE" -b 1024 -F "$OUT/rootfs.img" "$BLOCKS"

# Assert the output exists so a silent mke2fs failure surfaces here rather than
# downstream as a missing materialize output.
[ -s "$OUT/rootfs.img" ] || {
  echo "ERROR: mke2fs did not produce $OUT/rootfs.img" >&2
  ls -la "$OUT" >&2 || true
  exit 1
}
echo "built rootfs.img: $(wc -c < "$OUT/rootfs.img") bytes"
