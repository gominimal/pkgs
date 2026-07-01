let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
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

let version = "6.12.94" in
{
  name = "virtio-linux",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/linux-%{version}.tar.xz",
      sha256 = "e998a232b9418db3301cb58468e291a4f41d6ab8306029b30d991f56251dc8d2",
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
} | BuildSpec
