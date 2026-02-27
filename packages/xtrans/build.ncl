let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.6.0" in
{
  name = "xtrans",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/xtrans-%{version}.tar.xz",
      sha256 = "faafea166bf2451a173d9d593352940ec6404145c5d1da5c213423ce4d359e92",
      extract = true,
      strip_prefix = "xtrans-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [],

  cmd = "./build.sh",

  outputs = {
    includes = { glob = "usr/include/X11/Xtrans/**" } | OutputData,
    pkgconfig = { glob = "usr/share/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
