let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let sed = import "../sed/build.ncl" in
let make = import "../make/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.14.1" in
{
  name = "freetype",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # https://downloads.sourceforge.net/freetype/freetype-2.14.1.tar.xz
      url = "gs://minimal-staging-archives/freetype-%{version}.tar.xz",
      sha256 = "32427e8c471ac095853212a37aef816c60b42052d4d9e48230bab3bdf2936ccc",
      extract = true,
      strip_prefix = "freetype-%{version}",
    } | Source,
    base,
    toolchain,
    sed,
    make,
  ],
  runtime_deps = [
    glibc,
    libpng,
  ],

  cmd = "./build.sh",

  outputs = {
    freetype-config = { glob = "usr/bin/freetype-config" } | OutputBin,

    libs = { glob = "usr/lib/libfreetype*.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/**/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs.upstream_version = version,
} | BuildSpec
