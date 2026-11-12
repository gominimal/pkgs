let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let bc = import "../bc/build.ncl" in
let bison = import "../bison/build.ncl" in
let elfutils = import "../elfutils/build.ncl" in
let flex = import "../flex/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let perl = import "../perl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "6.12.117" in
{
  name = "virtio-linux",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/linux-%{version}.tar.xz",
      sha256 = "74e99aa5e60e242e0a165fed8cb2ea0d054bf7a401f01861d403d75733456613",
      extract = true,
      strip_prefix = "linux-%{version}",
    } | Source,
    base,
    bc,
    bison,
    elfutils,
    flex,
    m4,
    make,
    openssl,
    perl,
    pkgconf,
    toolchain,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    vmlinuz = { glob = "usr/share/virtio-linux/vmlinuz" } | OutputData,
    config = { glob = "usr/share/virtio-linux/config" } | OutputData,
    system_map = { glob = "usr/share/virtio-linux/System.map" } | OutputData,
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
              d=/usr/share/virtio-linux
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
