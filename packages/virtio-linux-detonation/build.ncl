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

# Detonation observability kernel. Intentionally diverged from virtio-linux's
# 6.12.43 base to the 6.18 LTS line (6.18 is longterm; no 7.x line is longterm
# as of 2026-08) for the materially newer BPF verifier +
# features the in-VM eBPF observer needs (the 6.12 verifier rejected the env-scan
# tracepoint with E2BIG). Same BPF-LSM/BTF/AUDIT config delta (see build.sh) and
# the dwarves build_dep that supplies `pahole` for CONFIG_DEBUG_INFO_BTF. Source
# moved off the gs:// staging mirror (only 6.1/6.12 staged there) to cdn.kernel.org,
# matching the libkrunfw package's accepted pattern.
let version = "6.18.63" in
{
  name = "virtio-linux-detonation",

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
    # CONFIG_DEBUG_INFO_BTF builds tools/bpf/resolve_btfids, whose vendored
    # libbpf generates bpf_helper_defs.h via a python3 script.
    python,
    toolchain,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    vmlinuz = { glob = "usr/share/virtio-linux-detonation/vmlinuz" } | OutputData,
    config = { glob = "usr/share/virtio-linux-detonation/config" } | OutputData,
    system_map = { glob = "usr/share/virtio-linux-detonation/System.map" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only WITH Linux-syscall-note",
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
              d=/usr/share/virtio-linux-detonation
              test -s $d/vmlinuz
              test -s $d/System.map
              [[ $(< $d/config) == *CONFIG_VIRTIO_BLK=y* ]]
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
