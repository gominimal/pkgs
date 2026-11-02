let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2026_10_02.cba3570" in
{
  name = "pasta",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://passt.top/passt/snapshot/passt-%{version}.tar.gz",
      sha256 = "7b81892b1070521ed217de672cdce43d7a37436e6f850cd04f2b63919ac484b6",
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
