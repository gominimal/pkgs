let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let e2fsprogs = import "../e2fsprogs/build.ncl" in
let git = import "../git/build.ncl" in
let socat = import "../socat/build.ncl" in
{
  name = "microvm-rootfs",

  # A read-only ext4 guest rootfs for a libkrun microVM. build.sh snapshots the
  # runtime userland (base + socat + git), drops in a small bring-up init, prunes
  # build-only bulk, and packs an ext4 image to load as a virtio-blk block
  # device. e2fsprogs is build-only — it provides mke2fs to pack the image — and
  # its files are removed from the tree before packing, so the runtime image
  # ships only the runtime closure. git is in the runtime closure because the
  # in-guest minimald session bring-up inits a minimal context that shells out
  # to git.
  runtime_deps = [
    base,
    socat,
    git,
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
