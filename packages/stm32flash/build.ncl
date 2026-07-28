let { standaloneTest, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.7" in
{
  name = "stm32flash",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.sourceforge.net/project/stm32flash/stm32flash-%{version}.tar.gz",
      sha256 = "c4c9cd8bec79da63b111d15713ef5cc2cd947deca411d35d6e3065e227dc414a",
      extract = true,
      strip_prefix = "stm32flash-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/stm32flash" } | OutputBin,
  },

  tests = {
    smoketest = standaloneTest "/bin/stm32flash -h",
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'Sourceforge,
      name = "stm32flash",
    },
    license_spdx = "GPL-2.0-or-later",
  },
} | BuildSpec
