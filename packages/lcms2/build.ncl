let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.17" in
{
  name = "lcms2",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/mm2/Little-CMS/releases/download/lcms2.17/lcms2-2.17.tar.gz
      url = "gs://minimal-staging-archives/lcms2-%{version}.tar.gz",
      sha256 = "d11af569e42a1baa1650d20ad61d12e41af4fead4aa7964a01f93b08b53ab074",
      extract = true,
      strip_prefix = "lcms2-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/liblcms2*.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
} | BuildSpec
