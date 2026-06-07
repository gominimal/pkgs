let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let socat = import "../socat/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let e2fsprogs = import "../e2fsprogs/build.ncl" in
{
  name = "minvmd-rootfs",

  # Guest rootfs for the minvmd microVM, as a read-only ext4 image. build.sh
  # snapshots the closure of these build_deps (socat + bash + coreutils + their
  # libs; e2fsprogs provides mke2fs at build time), drops in the bring-up init +
  # the /etc/minvmd/manifest boot contract, prunes build-only bulk, and packs an
  # ext4 image. minvmd loads it via krun_add_disk2 as /dev/vda.
  build_deps = [
    { file = "build.sh" } | Local,
    socat,
    bash,
    coreutils,
    e2fsprogs,
  ],

  cmd = "./build.sh",

  outputs = {
    rootfs = { glob = "usr/share/minvmd-rootfs/rootfs.img" } | OutputData,
  },
} | BuildSpec
