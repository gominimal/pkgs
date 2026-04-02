let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2026_01_20.386b5f5" in
{
  name = "pasta",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://passt.top/passt/snapshot/passt-%{version}.tar.gz",
      sha256 = "b378b36cc6d17988fd8efdc9e432495afc96787c3ee231aee55bc7e50c4edf6d",
      extract = true,
      strip_prefix = "passt-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    pasta = { glob = "usr/bin/pasta" } | OutputBin,
    passt = { glob = "usr/bin/passt" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
