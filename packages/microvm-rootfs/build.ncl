let { subsetOf, BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let e2fsprogs = import "../e2fsprogs/build.ncl" in
let git = import "../git/build.ncl" in
let iproute2 = import "../iproute2/build.ncl" in
let util-linux = import "../util-linux/build.ncl" in
{
  name = "microvm-rootfs",

  # A read-only ext4 guest userland for a libkrun microVM. build.sh snapshots
  # the runtime closure (base + git + networking tools), prunes build-only bulk,
  # and packs an ext4 image loaded as a virtio-blk block device (/dev/vda). The
  # guest minimald ships as the initramfs pid-1, mounts this image, and chroots
  # into it — there is no standalone init in the image itself. e2fsprogs is
  # build-only (mke2fs to pack the image) and its files are removed before
  # packing, so the image ships only the runtime closure. git is in the closure
  # because the in-guest minimald session bring-up inits a minimal context that
  # shells out to git. iproute2 (ip) and util-linux's nsenter give the guest
  # network/namespace plumbing — only the nsenter output is pulled from
  # util-linux (subsetOf), not its whole ~18 MB toolset.
  runtime_deps = [
    base,
    git,
    iproute2,
    subsetOf util-linux ["nsenter"],
  ],
  build_deps = [
    { file = "build.sh" } | Local,
    e2fsprogs,
  ],

  cmd = "./build.sh",

  outputs = {
    rootfs = { glob = "usr/share/microvm-rootfs/rootfs.img" } | OutputData,
  },
} | BuildSpec
