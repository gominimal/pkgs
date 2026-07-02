let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let libx11 = import "../libx11/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "6.0.2" in
{
  name = "libxfixes",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libXfixes-%{version}.tar.xz",
      sha256 = "39f115d72d9c5f8111e4684164d3d68cc1fd21f9b27ff2401b08fddfc0f409ba",
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
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
