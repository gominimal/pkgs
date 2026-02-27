let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.0.12" in
{
  name = "libxau",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libXau-%{version}.tar.xz",
      sha256 = "74d0e4dfa3d39ad8939e99bda37f5967aba528211076828464d2777d477fc0fb",
      extract = true,
      strip_prefix = "libXau-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xorgproto,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libXau.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
