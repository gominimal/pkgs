let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let glib = import "../glib/build.ncl" in
let expat = import "../expat/build.ncl" in
let libjpeg-turbo = import "../libjpeg-turbo/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let libwebp = import "../libwebp/build.ncl" in
let lcms2 = import "../lcms2/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "8.18.3" in
{
  name = "libvips",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/libvips/libvips/releases/download/v%{version}/vips-%{version}.tar.xz",
      sha256 = "f41285b61bfb495605494f074ca341f7791a1d406e2f157dcea606ef1ae1b146",
      extract = true,
      strip_prefix = "vips-%{version}",
    } | Source,
    base,
    toolchain,
    meson,
    ninja,
    pkgconf,
  ],
  runtime_deps = [
    glib,
    expat,
    libjpeg-turbo,
    libpng,
    libwebp,
    lcms2,
    zlib,
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/vips*" } | OutputBin,
    libs = { glob = "usr/lib/libvips*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.1-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libvips",
        repo = "libvips",
      },
    } | Attrs,
} | BuildSpec
