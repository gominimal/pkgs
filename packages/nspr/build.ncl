let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.39" in
{
  name = "nspr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nspr-%{version}.tar.gz",
      sha256 = "bbd02ee87a55676063a63e5bc819e0227de2666b47307b2a0134414cdf42368e",
      extract = true,
      strip_prefix = "nspr-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/lib{nspr4,plc4,plds4}.so*" } | OutputLib,
    bins = { glob = "usr/bin/nspr-config", allow_missing_interpreter = true } | OutputBin,
    includes = { glob = "usr/include/nspr/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MPL-2.0",
    } | Attrs,
} | BuildSpec
