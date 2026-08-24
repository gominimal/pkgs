let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.40" in
{
  name = "nspr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nspr-%{version}.tar.gz",
      sha256 = "c0c1884c627f3db7a783f7c7314c695226b2043696791d15519e7e0578c19bdc",
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
