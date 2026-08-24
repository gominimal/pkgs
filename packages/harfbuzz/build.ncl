let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let freetype = import "../freetype/build.ncl" in
let glib = import "../glib/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "14.3.1" in
{
  name = "harfbuzz",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/harfbuzz-%{version}.tar.xz",
      sha256 = "9dae9538aae2ffdf70cec31f2c27bf68e2aaeeae3112688467697d5faf6194f7",
      extract = true,
      strip_prefix = "harfbuzz-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    freetype,
    glib,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libharfbuzz*.so*" } | OutputLib,
    includes = { glob = "usr/include/harfbuzz/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT-Modern-Variant",
      source_provenance = {
        category = 'GithubRepo,
        owner = "harfbuzz",
        repo = "harfbuzz",
      },
    } | Attrs,
} | BuildSpec
