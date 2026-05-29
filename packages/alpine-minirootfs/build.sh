#!/bin/bash
# Assemble the Alpine minirootfs guest tree directly into $OUTPUT_DIR.
#
# The captured output IS the guest root (consumed in directory form). No guest
# binaries are executed here — pure extract + overlay + write — so this builds
# identically regardless of host arch.
set -euo pipefail

mkdir -p "$OUTPUT_DIR"

# 1. Base Alpine minirootfs (per-arch tarball, fetched + sha256-verified by the
#    build graph). The arch suffix is globbed so build.sh stays arch-agnostic.
tar -xzf alpine-minirootfs-"$MINIMAL_ARG_VERSION"-*.tar.gz -C "$OUTPUT_DIR"

# 2. socat overlay + its transitive shared libs (readline -> ncurses-libs).
#    apks are gzip tarballs; extract to scratch and copy only the payload
#    (usr/), leaving the .apk metadata dotfiles out of the rootfs. Without
#    libreadline.so.8 / libncursesw.so.6, socat (guest pid-1) fails to load
#    with exit 127 and the VM panics on init.
mkdir -p socat-extract
tar -xzf socat-"$MINIMAL_ARG_SOCAT_VERSION".apk -C socat-extract
cp -a socat-extract/usr/. "$OUTPUT_DIR/usr/"

mkdir -p readline-extract
tar -xzf readline-"$MINIMAL_ARG_READLINE_VERSION".apk -C readline-extract
cp -a readline-extract/usr/. "$OUTPUT_DIR/usr/"

mkdir -p libncursesw-extract
tar -xzf libncursesw-"$MINIMAL_ARG_LIBNCURSESW_VERSION".apk -C libncursesw-extract
cp -a libncursesw-extract/usr/. "$OUTPUT_DIR/usr/"

# 3. Stub guest workload for VM boot verification. Both vsock ports LISTEN
#    inside the guest; the host is expected to connect inward.
cat > "$OUTPUT_DIR/sbin/stub-init" <<'STUB'
#!/bin/sh
# Stub guest workload — pid-1 for VM boot verification.
#
#   vsock 7350  READY marker — every host connection receives "READY\n"; the
#               host blocks on this read to confirm boot completion.
#   vsock 2222  echo bridge  — each host connection is cat-looped.
set -eu

# Mount /proc and /sys defensively in case the host init didn't already
# (already-mounted is non-fatal).
mount -t proc  proc /proc 2>/dev/null || true
mount -t sysfs sys  /sys  2>/dev/null || true

# READY marker. Per-connection children are reaped by this socat, not pid-1 —
# acceptable for a stub.
socat VSOCK-LISTEN:7350,fork SYSTEM:'echo READY' &

# Echo bridge. Becomes pid-1 via exec; reaps its own per-connection children.
exec socat VSOCK-LISTEN:2222,fork EXEC:cat
STUB
chmod 0755 "$OUTPUT_DIR/sbin/stub-init"

# 4. Guest-side contract, machine- and human-readable.
mkdir -p "$OUTPUT_DIR/etc/stub"
cat > "$OUTPUT_DIR/etc/stub/manifest" <<MANIFEST
# Stub guest rootfs contract
#
# format=directory
# exec_target=/sbin/stub-init
#
# vsock_port_ready=7350    guest LISTENs; emits "READY\n" per connection
# vsock_port_bridge=2222   guest LISTENs; echoes (cat) per connection
alpine=$MINIMAL_ARG_VERSION
socat=$MINIMAL_ARG_SOCAT_VERSION
MANIFEST

# 5. Standard mountpoint dirs. A file-glob won't capture an empty dir, so drop
#    a sentinel; the host mounts proc/sys/dev over these at boot. Alpine ships
#    proc/sys/dev as 0555, so make the dir writable before the sentinel.
for d in proc sys dev tmp run; do
  mkdir -p "$OUTPUT_DIR/$d"
  chmod u+w "$OUTPUT_DIR/$d"
  : > "$OUTPUT_DIR/$d/keep"
done

# Stub procfs target referenced by Alpine's /etc/mtab -> ../proc/mounts compat
# symlink. The sandbox check requires the link to resolve to something inside
# the output tree; at runtime procfs is mounted over this directory and the
# stub is shadowed.
: > "$OUTPUT_DIR/proc/mounts"

# 6. Rewrite in-rootfs absolute symlinks to relative form. Alpine ships busybox
#    multi-call links like /usr/sbin/ether-wake -> /bin/busybox; absolute
#    targets look like host-escapes to the build sandbox even though they
#    resolve correctly once the tree is mounted as /. Relative form preserves
#    the semantics and keeps the sandbox check happy.
cd "$OUTPUT_DIR"
find . -type l -print0 | while IFS= read -r -d '' link; do
  target=$(readlink "$link")
  case "$target" in
    /*)
      link_dir=$(dirname "$link")
      rel=$(realpath -m -s --relative-to="$link_dir" "./${target#/}")
      ln -sfn "$rel" "$link"
      ;;
  esac
done
cd - >/dev/null
