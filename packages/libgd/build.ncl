let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let fontconfig = import "../fontconfig/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libjpeg-turbo = import "../libjpeg-turbo/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "2.3.3" in
{
  name = "libgd",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/libgd/libgd/releases/download/gd-%{version}/libgd-%{version}.tar.gz",
      sha256 = "dd3f1f0bb016edcc0b2d082e8229c822ad1d02223511997c80461481759b1ed2",
      extract = true,
      strip_prefix = "libgd-%{version}",
    } | Source,
    base,
    cmake,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    fontconfig,
    freetype,
    glibc,
    libjpeg-turbo,
    libpng,
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "GD",
    source_provenance = {
      category = 'GithubRepo,
      owner = "libgd",
      repo = "libgd",
    },
  },
} | BuildSpec
