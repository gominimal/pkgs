let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2026_07_28.f8df3f1" in
{
  name = "pasta",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://passt.top/passt/snapshot/passt-%{version}.tar.gz",
      sha256 = "2b3effb3dcd1f6b1b46da3a2419c037508d24bc39f90513bbbb660e8eb6520e5",
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
