let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in
let xtrans = import "../xtrans/build.ncl" in

let libxcb = import "../libxcb/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.8.13" in
{
  name = "libx11",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libX11-%{version}.tar.xz",
      sha256 = "69606f485c2c07c14ef64f75b7bb326d48587af33795d9ab3e607c0b5f94f11c",
      extract = true,
      strip_prefix = "libX11-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xorgproto,
    xtrans,
  ],
  runtime_deps = [
    libxcb,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libX11*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
