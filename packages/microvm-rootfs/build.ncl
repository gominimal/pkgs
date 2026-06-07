let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let socat = import "../socat/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let e2fsprogs = import "../e2fsprogs/build.ncl" in
{
  name = "microvm-rootfs",

  # A read-only ext4 guest rootfs for a libkrun microVM. build.sh snapshots the
  # closure of these build_deps (socat + bash + coreutils + their libs;
  # e2fsprogs provides mke2fs at build time), drops in a small bring-up init,
  # prunes build-only bulk, and packs an ext4 image to load as a virtio-blk
  # block device.
  build_deps = [
    { file = "build.sh" } | Local,
    socat,
    bash,
    coreutils,
    e2fsprogs,
  ],

  cmd = "./build.sh",

  outputs = {
    rootfs = { glob = "usr/share/microvm-rootfs/rootfs.img" } | OutputData,
  },
} | BuildSpec
