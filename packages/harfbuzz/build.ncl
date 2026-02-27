let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let glib = import "../glib/build.ncl" in
let freetype = import "../freetype/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "12.3.2" in
{
  name = "harfbuzz",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/harfbuzz-%{version}.tar.xz",
      sha256 = "6f6db164359a2da5a84ef826615b448b33e6306067ad829d85d5b0bf936f1bb8",
      extract = true,
      strip_prefix = "harfbuzz-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
    glib,
    freetype,
  ],
  runtime_deps = [
    freetype,
    glib,
    glibc,
    gcc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libharfbuzz*.so*" } | OutputLib,
    includes = { glob = "usr/include/harfbuzz/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
    } | Attrs,
} | BuildSpec
