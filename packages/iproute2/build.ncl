let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bison = import "../bison/build.ncl" in
let flex = import "../flex/build.ncl" in
let m4 = import "../m4/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let libcap = import "../libcap/build.ncl" in

let version = "6.18.0" in
{
  name = "iproute2",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/iproute2-%{version}.tar.xz",
      sha256 = "6ba520e1975e4c50dc931eeae91ea37c198b8a173744885f8895b84325f9d456",
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
      repology_project = "iproute2",
    } | Attrs,
} | BuildSpec
