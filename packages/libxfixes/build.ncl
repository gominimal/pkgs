let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let libx11 = import "../libx11/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "6.0.1" in
{
  name = "libxfixes",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libXfixes-%{version}.tar.xz",
      sha256 = "b695f93cd2499421ab02d22744458e650ccc88c1d4c8130d60200213abc02d58",
      extract = true,
      strip_prefix = "libXfixes-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xorgproto,
  ],
  runtime_deps = [
    libx11,
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libXfixes.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
