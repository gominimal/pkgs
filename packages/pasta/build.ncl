let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2026_06_11.a9c61ff" in
{
  name = "pasta",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://passt.top/passt/snapshot/passt-%{version}.tar.gz",
      sha256 = "0454f7bdd55ff560475dc68ace517075786eb35bb18423280971d61ed3223b84",
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
      license_spdx = "GPL-2.0-or-later",
    } | Attrs,
} | BuildSpec
