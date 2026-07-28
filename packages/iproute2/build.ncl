let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bison = import "../bison/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let flex = import "../flex/build.ncl" in
let m4 = import "../m4/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let bash = import "../bash/build.ncl" in
let libcap = import "../libcap/build.ncl" in

let version = "7.1.0" in
{
  name = "iproute2",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/iproute2-%{version}.tar.xz",
      sha256 = "fd9fa1b95809417157ca83dd72957e3261bdbce896353cb936f80af0b33a4b5c",
      extract = true,
      strip_prefix = "iproute2-%{version}",
    } | Source,
    base,
    bison,
    flex,
    m4,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    bash, # needed by /usr/sbin/routel
    coreutils, # needed by /usr/sbin/routel
    libcap,
  ],
  cmd = "./build.sh",
  outputs = {
    sbins = { glob = "usr/sbin/*" } | OutputBin,

    includes = { glob = "usr/include/iproute2/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
      repology_project = "iproute2",
    } | Attrs,
} | BuildSpec
