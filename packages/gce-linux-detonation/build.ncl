let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let bc = import "../bc/build.ncl" in
let bison = import "../bison/build.ncl" in
let dwarves = import "../dwarves/build.ncl" in
let elfutils = import "../elfutils/build.ncl" in
let flex = import "../flex/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let perl = import "../perl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let virtio-linux-detonation = import "../virtio-linux-detonation/build.ncl" in

# The detonation observability kernel for a Google Compute Engine host.
#
# virtio-linux-detonation is a microVM guest kernel: it has virtio drivers
# only, so it cannot find the disk (NVMe) or the network (gVNIC) of the C4 and
# C4A machines the build hosts run on. This is the same kernel source with the
# same BPF-LSM, BTF and tracing settings, plus what such a host needs to boot
# and run its userspace. build.sh compares those settings with the config
# virtio-linux-detonation ships and fails on any difference, so the two cannot
# drift apart (gominimal/build-servers#353: the Package Build Log's sensor was
# written for that kernel).
#
# Everything is built in: there are no modules to install, only the image.
#
# Same source and version as virtio-linux-detonation, on purpose.
let version = "6.18.63" in
{
  name = "gce-linux-detonation",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-%{version}.tar.xz",
      sha256 = "81764a545072d160748beff4d9de2e7d95aa9f16e8261110288f067a2cc61d71",
      extract = true,
      strip_prefix = "linux-%{version}",
    } | Source,
    base,
    bc,
    bison,
    dwarves,
    elfutils,
    flex,
    m4,
    make,
    openssl,
    perl,
    pkgconf,
    python,
    toolchain,
    # For its config only: the settings this kernel must match.
    virtio-linux-detonation,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    vmlinuz = { glob = "usr/share/gce-linux-detonation/vmlinuz" } | OutputData,
    config = { glob = "usr/share/gce-linux-detonation/config" } | OutputData,
    system_map = { glob = "usr/share/gce-linux-detonation/System.map" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only WITH Linux-syscall-note",
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%%"
              set -e
              d=/usr/share/gce-linux-detonation
              test -s $d/vmlinuz
              test -s $d/System.map
              c=$(< $d/config)
              for sym in BPF_LSM DEBUG_INFO_BTF GVE BLK_DEV_NVME EXT4_FS EFI_STUB TCG_TPM NF_TABLES IKCONFIG_PROC; do
                [[ $c == *"CONFIG_$sym=y"* ]] || { echo "CONFIG_$sym is not y"; exit 1; }
              done
              [[ $c != *"=m"* ]] || { echo "the config still has modules"; exit 1; }
              case $(uname -m) in
                aarch64) test "$(od -An -tx1 -N2 $d/vmlinuz)" = ' 1f 8b' ;;
                x86_64) test "$(od -An -c -j514 -N4 $d/vmlinuz | tr -d ' ')" = HdrS ;;
              esac
            "%%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
