let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let e2fsprogs = import "../e2fsprogs/build.ncl" in
let git = import "../git/build.ncl" in
let iproute2 = import "../iproute2/build.ncl" in
let util-linux = import "../util-linux/build.ncl" in
{
  name = "microvm-rootfs",

  # A read-only ext4 guest userland for a libkrun microVM. build.sh snapshots
  # the runtime closure, prunes build-only bulk, and packs an ext4 image loaded
  # as a virtio-blk block device (/dev/vda). The guest minimald ships as the
  # initramfs pid-1, mounts this image, and chroots into it — there is no
  # standalone init in the image itself. git is in the closure because the
  # in-guest minimald session bring-up inits a minimal context that shells out
  # to git. iproute2 (ip) and util-linux's nsenter give the guest
  # network/namespace plumbing. e2fsprogs ships mkfs.ext4 (and mke2fs, which
  # also packs the image below) so the guest minimald can format the per-VM
  # writable volume (/dev/vdb) on first boot; util-linux ships fstrim to reclaim
  # space from that volume (its full toolset also carries the nsenter above).
  # The mountpoint /var/lib/minimal is staged as an empty dir since the
  # read-only root cannot be mkdir'd at runtime.
  runtime_deps = [
    base,
    e2fsprogs,
    git,
    iproute2,
    util-linux,
  ],
  build_deps = [
    { file = "build.sh" } | Local,
  ],

  cmd = "./build.sh",

  outputs = {
    rootfs = { glob = "usr/share/microvm-rootfs/rootfs.img" } | OutputData,
  },
} | BuildSpec
