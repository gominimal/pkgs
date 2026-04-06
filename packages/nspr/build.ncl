let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.38.2" in
{
  name = "nspr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nspr-%{version}.tar.gz",
      sha256 = "e4092faeab77bdc9b32db1113e4215948ee768e26c4666db3b5a60b35f2c9105",
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
    } | Attrs,
} | BuildSpec
